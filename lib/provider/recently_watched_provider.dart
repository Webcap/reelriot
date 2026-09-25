import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/utils/globals.dart';
import 'package:reelriot/controller/recently_watched_database_controller.dart';
import 'package:reelriot/models/recently_watched.dart';
import 'package:reelriot/models/tv.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reelriot/widgets/mobile_context_menu.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/api/endpoints.dart';

class RecentProvider extends ChangeNotifier {
  static RecentProvider? _instance;
  static RecentProvider get instance => _instance ??= RecentProvider();

  RecentProvider() {
    _instance = this;
    _loadCachedWatchStats();
  }

  final RecentlyWatchedMoviesController _movieController =
      RecentlyWatchedMoviesController();
  final RecentlyWatchedEpisodeController _episodeController =
      RecentlyWatchedEpisodeController();

  int? _apiMovieWatchTimeMinutes;
  int? _apiTvWatchTimeMinutes;
  bool _isLoadingWatchStats = false;
  bool get isLoadingWatchStats => _isLoadingWatchStats;

  List<RecentMovie> _movies = [];
  List<RecentMovie> get movies => _movies;

  /// Rewatch counts, keyed by movie id. Refreshed whenever [_movies] refreshes.
  final Map<int, int> _movieWatchCounts = {};
  int movieWatchCount(int movieId) => _movieWatchCounts[movieId] ?? 0;

  /// Rewatch counts, keyed by "seriesId_seasonNum_episodeNum".
  final Map<String, int> _episodeWatchCounts = {};
  String _episodeWatchKey(int seriesId, int seasonNum, int episodeNum) =>
      '${seriesId}_${seasonNum}_$episodeNum';
  int episodeWatchCount(int seriesId, int seasonNum, int episodeNum) =>
      _episodeWatchCounts[_episodeWatchKey(seriesId, seasonNum, episodeNum)] ?? 0;
  List<RecentMovie> get continueWatchingMovies => _movies
      .where((m) => shouldShowInContinueWatching(m.elapsed, m.remaining))
      .toList();

  List<RecentEpisode> _episodes = [];
  List<RecentEpisode> get episodes => _episodes;
  List<RecentEpisode> get continueWatchingEpisodes => _episodes
      .where((e) => shouldShowInContinueWatching(e.elapsed, e.remaining))
      .toList();

  List<RecentEpisode> _inProgressEpisodes = [];
  List<RecentEpisode> get inProgressEpisodes => continueWatchingEpisodes;

  List<RecentEpisode> _upNextEpisodes = [];
  List<RecentEpisode> get upNextEpisodes => _upNextEpisodes;

  final Map<int, TVDetails> _tvDetailsCache = {};
  final Map<int, RecentEpisode> _nextEpisodeCache = {};
  bool _isCalculatingUpNext = false;

  bool _isProxyEnabled = false;
  String _proxyUrl = '';
  String _language = 'en';

  // ---------------------------------------------------------------------------
  // Supabase Realtime
  // ---------------------------------------------------------------------------

  /// Active Realtime channel subscription (one per user session).
  RealtimeChannel? _realtimeChannel;

  /// Debounce timer that coalesces rapid Realtime events into a single sync.
  Timer? _realtimeSyncDebounce;

  /// Set to true once the Realtime channel is subscribed to avoid duplicates.
  bool _realtimeSubscribed = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Subscribes to INSERT/UPDATE events on [playback_history_events] for the
  /// current user and triggers a debounced [syncFromCloud] on each event.
  void _subscribeRealtime(String uid) {
    if (_realtimeSubscribed) return;
    _realtimeSubscribed = true;

    _realtimeChannel = _supabase
        .channel('watch-history-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'playback_history_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) {
            debugPrint('[RecentProvider] 🔔 Realtime event — debouncing sync');
            _realtimeSyncDebounce?.cancel();
            _realtimeSyncDebounce = Timer(
              const Duration(seconds: 2),
              () => syncFromCloud(),
            );
          },
        )
        .subscribe();

    debugPrint('[RecentProvider] 📡 Realtime channel subscribed for user $uid');
  }

  /// Tears down the Realtime subscription and any pending debounce timer.
  Future<void> unsubscribeRealtime() async {
    _realtimeSyncDebounce?.cancel();
    _realtimeSyncDebounce = null;
    if (_realtimeChannel != null) {
      await _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    _realtimeSubscribed = false;
  }

  void updateConfig(
      {required bool isProxyEnabled,
      required String proxyUrl,
      required String language}) {
    _isProxyEnabled = isProxyEnabled;
    _proxyUrl = proxyUrl;
    _language = language;
  }

  /// Clears in-memory and local SQLite history data.
  Future<void> clearLocalData() async {
    _movies = [];
    _episodes = [];
    _movieWatchCounts.clear();
    _episodeWatchCounts.clear();
    _apiMovieWatchTimeMinutes = null;
    _apiTvWatchTimeMinutes = null;
    await _movieController.clearAllMovies();
    await _episodeController.clearAllEpisodes();
    await sharedPrefsSingleton.remove('cached_movie_watch_mins');
    await sharedPrefsSingleton.remove('cached_tv_watch_mins');
    await sharedPrefsSingleton.remove('last_synced_user_id');
    // Tear down Realtime subscription so a new session gets a fresh channel.
    await unsubscribeRealtime();
    notifyListeners();
  }

  /// Fetches cloud watch_history from Caffeine API.
  /// When a new account signs in (or forceReplace is true), local DB is replaced completely
  /// with the logged-in user's cloud data to prevent cross-account history leakage.
  Future<void> syncFromCloud({bool forceReplace = false}) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history?limit=100');

      final res = await http
          .get(url, headers: caffeineApiHeaders)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['history'] != null) {
          final List<dynamic> history = body['history'];
          final List<RecentMovie> cloudMovies = [];
          final List<RecentEpisode> cloudEpisodes = [];

          for (var row in history) {
            final isTv = row['media_type'] == 'tv';
            final isCompleted = row['completed'] == true;
            final elapsed = _ensureMs((row['elapsed_ms'] as num?)?.toInt() ?? 0);
            final remaining = (row['remaining_ms'] as num?)?.toInt() ?? 0;

            if (isTv) {
              final seriesId = (row['id'] as num?)?.toInt();
              final sNum = (row['season_num'] as num?)?.toInt() ?? 1;
              final eNum = (row['episode_num'] as num?)?.toInt() ?? 1;
              final epId = seriesId != null
                  ? (seriesId * 10000 + sNum * 100 + eNum)
                  : (sNum * 100 + eNum);

              cloudEpisodes.add(RecentEpisode(
                id: epId,
                seriesId: seriesId,
                seriesName: row['title'],
                episodeName: row['episode_name'],
                posterPath: row['poster_path'],
                seasonNum: sNum,
                episodeNum: eNum,
                elapsed: elapsed,
                remaining: isCompleted ? 0 : remaining,
                dateTime: row['updated_at'],
              ));
            } else {
              cloudMovies.add(RecentMovie(
                id: (row['id'] as num?)?.toInt(),
                title: row['title'],
                posterPath: row['poster_path'],
                backdropPath: row['backdrop_path'],
                releaseYear: null,
                elapsed: elapsed,
                remaining: isCompleted ? 0 : remaining,
                dateTime: row['updated_at'],
              ));
            }
          }

          // Cloud is the single source of truth for watch history; directly update in-memory controllers.
          _movies = cloudMovies;
          _episodes = cloudEpisodes;
          await _movieController.replaceAllMovies(cloudMovies);
          await _episodeController.replaceAllEpisodes(cloudEpisodes);

          await sharedPrefsSingleton.setString('last_synced_user_id', uid);
        }
      }
    } catch (e) {
      debugPrint('[WatchHistory] ❌ syncFromCloud API error: $e');
    }

    await fetchMovies();
    await fetchEpisodes();

    // Subscribe to Realtime after the first successful sync so cross-device
    // progress updates are reflected instantly without a full app restart.
    _subscribeRealtime(uid);
  }

  Future<void> fetchMovies() async {
    _movies = await _movieController.getRecentMovieList();
    for (final m in _movies) {
      if (m.id == null) continue;
      _movieWatchCounts[m.id!] = await _movieController.getWatchCount(m.id!);
    }
    notifyListeners();
  }

  Future<void> addMovie(RecentMovie movie) async {
    await _movieController.insertMovie(movie);
    await fetchMovies();
  }

  /// Trakt-style "add a watch": logs a new watch event for [movie] every time
  /// it's called, incrementing its rewatch count. If the movie isn't already
  /// marked watched, it's also upserted into the progress table first so it
  /// shows as watched immediately (mirrors the previous single-tap behavior).
  Future<void> addMovieWatch(RecentMovie movie, {String? watchedAt}) async {
    if (movie.id == null) return;
    final matches = _movies.where((m) => m.id == movie.id);
    final alreadyWatched = matches.isNotEmpty &&
        isWatchedProgress(matches.first.elapsed, matches.first.remaining);
    if (!alreadyWatched) {
      await _movieController.insertMovie(movie);
    }

    final event = WatchEvent(
      eventId: generateWatchEventId(),
      mediaId: movie.id!,
      watchedAt: watchedAt ?? DateTime.now().toIso8601String(),
    );
    await _movieController.insertWatchEvent(
      event,
      title: movie.title,
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
    );

    await fetchMovies();
    await invalidateAndRefreshWatchStats();
  }

  Future<List<WatchEvent>> getMovieWatchHistory(int movieId) =>
      _movieController.getWatchEvents(movieId);

  /// Removes a single logged watch. If no watches remain, the movie reverts
  /// to unwatched (matches the pre-rewatch "unmark as watched" behavior).
  Future<void> removeMovieWatchEvent(int movieId, String eventId) async {
    await _movieController.deleteWatchEvent(eventId);
    final remaining = await _movieController.getWatchCount(movieId);
    _movieWatchCounts[movieId] = remaining;
    if (remaining == 0) {
      await deleteMovie(movieId);
    } else {
      notifyListeners();
    }
  }

  Future<void> updateMovie(RecentMovie movie, int id) async {
    await _movieController.updateMovie(movie, id);
    await fetchMovies();
  }

  Future<void> deleteMovie(int id) async {
    await _movieController.deleteMovie(id);
    await fetchMovies();
    await invalidateAndRefreshWatchStats();
  }

  Future<void> markMovieAsCompleted(RecentMovie movie) async {
    final updated = RecentMovie(
      id: movie.id,
      title: movie.title,
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
      releaseYear: movie.releaseYear,
      elapsed: (movie.elapsed ?? 0) + (movie.remaining ?? 0),
      remaining: 0,
      dateTime: DateTime.now().toIso8601String(),
    );
    if ((updated.elapsed ?? 0) == 0) {
      updated.elapsed = 7200000; // default 2hr if no progress
    }
    await updateMovie(updated, movie.id!);
    await invalidateAndRefreshWatchStats();
  }

  /// Episode

  Future<void> fetchEpisodes(
      {bool? isProxyEnabled, String? proxyUrl, String? language}) async {
    if (isProxyEnabled != null) _isProxyEnabled = isProxyEnabled;
    if (proxyUrl != null) _proxyUrl = proxyUrl;
    if (language != null) _language = language;

    _episodes = await _episodeController.getEpisodeList();
    for (final e in _episodes) {
      final seriesId = e.seriesId ?? e.id;
      if (seriesId == null || e.seasonNum == null || e.episodeNum == null) {
        continue;
      }
      _episodeWatchCounts[_episodeWatchKey(seriesId, e.seasonNum!, e.episodeNum!)] =
          await _episodeController.getWatchCount(
              seriesId, e.seasonNum!, e.episodeNum!);
    }
    await _calculateUpNext();
    notifyListeners();
  }

  Future<void> _calculateUpNext() async {
    if (_isCalculatingUpNext) return;
    _isCalculatingUpNext = true;

    try {
      final Map<int, RecentEpisode> latestBySeries = {};
      for (final e in _episodes) {
        if (e.seriesId == null) continue;
        final existing = latestBySeries[e.seriesId!];
        if (existing == null) {
          latestBySeries[e.seriesId!] = e;
        } else {
          final exDate =
              DateTime.tryParse(existing.dateTime ?? '') ?? DateTime(0);
          final eDate = DateTime.tryParse(e.dateTime ?? '') ?? DateTime(0);
          if (eDate.isAfter(exDate)) {
            latestBySeries[e.seriesId!] = e;
          }
        }
      }

      final List<RecentEpisode> result = [];
      final List<RecentEpisode> inProgressList = [];
      final episodesToAdvance = <RecentEpisode>[];

      for (var e in latestBySeries.values) {
        if (!shouldShowInContinueWatching(e.elapsed, e.remaining)) {
          episodesToAdvance.add(e);
        } else {
          inProgressList.add(e);
        }
      }

      // Handle advancement for completed episodes
      for (var completedEp in episodesToAdvance) {
        final seriesId = completedEp.seriesId!;

        // Try to find/fetch next episode metadata
        RecentEpisode? nextEp = _nextEpisodeCache[seriesId];

        // If nextEp's season/episode matches what we just finished, it's stale
        if (nextEp != null &&
            nextEp.seasonNum == completedEp.seasonNum &&
            nextEp.episodeNum == completedEp.episodeNum) {
          nextEp = null;
        }

        if (nextEp == null) {
          try {
            // 1. Fetch show-level details to see season structure
            TVDetails? showDetails = _tvDetailsCache[seriesId];
            if (showDetails == null) {
              showDetails = await fetchTVDetails(
                  Endpoints.tvDetailsUrl(seriesId, _language),
                  _isProxyEnabled,
                  _proxyUrl);
              _tvDetailsCache[seriesId] = showDetails;
            }

            if (showDetails.seasons != null) {
              final s = completedEp.seasonNum ?? 1;
              final e = completedEp.episodeNum ?? 1;

              // Find current season info
              final currentSeasonInfo = showDetails.seasons!.firstWhere(
                (se) => se.seasonNumber == s,
                orElse: () => Seasons(),
              );

              int targetSeason = s;
              int targetEpisode = e + 1;

              // If finished last episode of season, try next season
              if (currentSeasonInfo.episodeCount != null &&
                  e >= currentSeasonInfo.episodeCount!) {
                targetSeason = s + 1;
                targetEpisode = 1;
              }

              // Check if target season exists
              final targetSeasonExists = showDetails.seasons!
                  .any((se) => se.seasonNumber == targetSeason);

              if (targetSeasonExists) {
                // Fetch Season Details
                final seasonDetails = await fetchTVDetails(
                    Endpoints.getSeasonDetails(
                        seriesId, targetSeason, _language),
                    _isProxyEnabled,
                    _proxyUrl);

                if (seasonDetails.episodes != null) {
                  final nextMetadata = seasonDetails.episodes!.firstWhere(
                    (ep) => ep.episodeNumber == targetEpisode,
                    orElse: () => EpisodeList(),
                  );

                  if (nextMetadata.episodeId != null) {
                    nextEp = RecentEpisode(
                      id: nextMetadata.episodeId,
                      seriesId: seriesId,
                      seriesName: completedEp.seriesName,
                      episodeName: nextMetadata.name,
                      episodeNum: nextMetadata.episodeNumber,
                      seasonNum: nextMetadata.seasonNumber,
                      posterPath: completedEp.posterPath,
                      elapsed: 0,
                      remaining: 3600,
                      dateTime: completedEp.dateTime,
                    );
                    _nextEpisodeCache[seriesId] = nextEp;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error advancing next episode for $seriesId: $e');
          }
        }

        if (nextEp != null) {
          result.add(nextEp);
        } else {
          // If no next episode, keep the completed one
          result.add(completedEp);
        }
      }

      _upNextEpisodes = result;
      _inProgressEpisodes = inProgressList;

      _upNextEpisodes.sort((a, b) {
        final da = a.dateTime ?? '';
        final db = b.dateTime ?? '';
        return db.compareTo(da);
      });
      _inProgressEpisodes.sort((a, b) {
        final da = a.dateTime ?? '';
        final db = b.dateTime ?? '';
        return db.compareTo(da);
      });
    } finally {
      _isCalculatingUpNext = false;
    }
  }

  Future<void> addEpisode(RecentEpisode episode) async {
    await _episodeController.insertTV(episode);
    await fetchEpisodes();
  }

  /// Trakt-style "add a watch" for an episode: logs a new watch event every
  /// time it's called, incrementing its rewatch count. If the episode isn't
  /// already marked watched, it's also upserted into the progress table first.
  Future<void> addEpisodeWatch(RecentEpisode episode, {String? watchedAt}) async {
    final seriesId = episode.seriesId ?? episode.id;
    if (seriesId == null ||
        episode.seasonNum == null ||
        episode.episodeNum == null) {
      return;
    }

    final matches = _episodes.where((e) =>
        (e.seriesId ?? e.id) == seriesId &&
        e.seasonNum == episode.seasonNum &&
        e.episodeNum == episode.episodeNum);
    final alreadyWatched = matches.isNotEmpty &&
        isWatchedProgress(matches.first.elapsed, matches.first.remaining);
    if (!alreadyWatched) {
      await _episodeController.insertTV(episode);
    }

    final event = WatchEvent(
      eventId: generateWatchEventId(),
      mediaId: seriesId,
      seasonNum: episode.seasonNum,
      episodeNum: episode.episodeNum,
      watchedAt: watchedAt ?? DateTime.now().toIso8601String(),
    );
    await _episodeController.insertWatchEvent(
      event,
      seriesId: seriesId,
      episodeId: episode.id,
      seriesName: episode.seriesName,
      episodeName: episode.episodeName,
      posterPath: episode.posterPath,
    );

    await fetchEpisodes();
    await invalidateAndRefreshWatchStats();
  }

  Future<List<WatchEvent>> getEpisodeWatchHistory(
          int seriesId, int seasonNum, int episodeNum) =>
      _episodeController.getWatchEvents(seriesId, seasonNum, episodeNum);

  /// Removes a single logged watch. If no watches remain, the episode reverts
  /// to unwatched (matches the pre-rewatch "unmark as watched" behavior).
  Future<void> removeEpisodeWatchEvent(RecentEpisode episode, String eventId) async {
    final seriesId = episode.seriesId ?? episode.id;
    if (seriesId == null ||
        episode.seasonNum == null ||
        episode.episodeNum == null ||
        episode.id == null) {
      return;
    }
    await _episodeController.deleteWatchEvent(eventId);
    final remaining = await _episodeController.getWatchCount(
        seriesId, episode.seasonNum!, episode.episodeNum!);
    _episodeWatchCounts[
            _episodeWatchKey(seriesId, episode.seasonNum!, episode.episodeNum!)] =
        remaining;
    if (remaining == 0) {
      await deleteEpisode(episode.id!, episode.episodeNum!, episode.seasonNum!);
    } else {
      notifyListeners();
    }
  }

  Future<void> updateEpisode(
      RecentEpisode episode, int id, int episodeNum, int seasonNum) async {
    await _episodeController.updateTV(episode, id, episodeNum, seasonNum);
    await fetchEpisodes();
  }

  Future<void> deleteEpisode(int id, int episodeNum, int seasonNum) async {
    await _episodeController.deleteTV(id, episodeNum, seasonNum);
    await fetchEpisodes();
    await invalidateAndRefreshWatchStats();
  }

  Future<void> markEpisodeAsCompleted(RecentEpisode episode) async {
    final updated = RecentEpisode(
      id: episode.id,
      seriesId: episode.seriesId,
      seriesName: episode.seriesName,
      episodeName: episode.episodeName,
      episodeNum: episode.episodeNum,
      seasonNum: episode.seasonNum,
      posterPath: episode.posterPath,
      elapsed: (episode.elapsed ?? 0) + (episode.remaining ?? 0),
      remaining: 0,
      dateTime: DateTime.now().toIso8601String(),
    );
    if ((updated.elapsed ?? 0) == 0) {
      updated.elapsed = 3600000; // default 1hr if no progress
    }
    await updateEpisode(
        updated, episode.id!, episode.episodeNum!, episode.seasonNum!);
    await invalidateAndRefreshWatchStats();
  }

  Future<void> markUntilEpisodeAsCompleted({
    required List<EpisodeList> allEpisodes,
    required EpisodeList targetEpisode,
    required int? tvId,
    required String? seriesName,
    required String? posterPath,
  }) async {
    for (var ep in allEpisodes) {
      if (ep.seasonNumber! < targetEpisode.seasonNumber! ||
          (ep.seasonNumber == targetEpisode.seasonNumber &&
              ep.episodeNumber! <= targetEpisode.episodeNumber!)) {
        final recentEp = RecentEpisode(
          id: ep.episodeId,
          seriesId: tvId,
          seriesName: seriesName,
          episodeName: ep.name,
          episodeNum: ep.episodeNumber,
          seasonNum: ep.seasonNumber,
          posterPath: posterPath,
          elapsed: 3600000,
          remaining: 0,
          dateTime: DateTime.now().toIso8601String(),
        );
        await _episodeController.insertTV(recentEp);
      }
    }
    await fetchEpisodes();
    await invalidateAndRefreshWatchStats();
  }

  /// Invalidates both local and server cache, then fetches fresh stats from the API
  Future<void> invalidateAndRefreshWatchStats() async {
    try {
      sharedPrefsSingleton.remove('cached_movie_watch_mins');
      sharedPrefsSingleton.remove('cached_tv_watch_mins');

      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
        final url = Uri.parse('$base/v1/user/$uid/watch-stats/cache');
        await http
            .delete(url, headers: caffeineApiHeaders)
            .timeout(const Duration(seconds: 4))
            .catchError((_) => http.Response('', 500));
      }
    } catch (e) {
      debugPrint('[RecentProvider] ⚠️ invalidateAndRefreshWatchStats error: $e');
    }

    // Immediately fetch updated watch stats and notify listeners
    await fetchWatchStatsFromApi();
  }


  void _loadCachedWatchStats() {
    try {
      _apiMovieWatchTimeMinutes =
          sharedPrefsSingleton.getInt('cached_movie_watch_mins');
      _apiTvWatchTimeMinutes =
          sharedPrefsSingleton.getInt('cached_tv_watch_mins');
    } catch (_) {}
  }

  /// Fetches server-side watch stats for completed items from Caffeine API
  Future<void> fetchWatchStatsFromApi() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse('$base/v1/user/$uid/watch-stats?days=14');

    try {
      _isLoadingWatchStats = true;
      final response = await http
          .get(url, headers: caffeineApiHeaders)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'];
          _apiMovieWatchTimeMinutes =
              (stats['movies']?['minutes'] as num?)?.toInt() ?? 0;
          _apiTvWatchTimeMinutes =
              (stats['tv']?['minutes'] as num?)?.toInt() ?? 0;

          // Cache on client
          await sharedPrefsSingleton.setInt(
              'cached_movie_watch_mins', _apiMovieWatchTimeMinutes!);
          await sharedPrefsSingleton.setInt(
              'cached_tv_watch_mins', _apiTvWatchTimeMinutes!);

          notifyListeners();
        }
      }
    } catch (_) {
      // Keep cached or fallback to local
    } finally {
      _isLoadingWatchStats = false;
    }
  }

  static int _ensureMs(int? value) {
    if (value == null) return 0;
    if (value > 0 && value < 50000) {
      return value * 1000;
    }
    return value;
  }

  String formatWatchTime(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}h${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Watch time (minutes) in last 2 weeks for movies, directly from cloud stats API.
  int get movieWatchTimeMinutesLast2Weeks => _apiMovieWatchTimeMinutes ?? 0;

  /// Watch time (minutes) in last 2 weeks for TV episodes, directly from cloud stats API.
  int get tvWatchTimeMinutesLast2Weeks => _apiTvWatchTimeMinutes ?? 0;
}
