import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:reelriot/models/recently_watched.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deletes any legacy local SQLite database files created by previous versions
/// of the app to ensure watch history is purely cloud-backed and not stored on Android storage.
Future<void> _cleanupLegacyDatabases() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final names = [
      'recent_movies.db',
      'recent_movies.db-journal',
      'recent_movies.db-wal',
      'recent_movies.db-shm',
      'recent_episodes.db',
      'recent_episodes.db-journal',
      'recent_episodes.db-wal',
      'recent_episodes.db-shm',
      'recent_episodes_v2.db',
      'recent_episodes_v2.db-journal',
      'recent_episodes_v2.db-wal',
      'recent_episodes_v2.db-shm',
    ];
    for (final name in names) {
      final f1 = File('${directory.path}/$name');
      if (await f1.exists()) {
        await f1.delete();
        debugPrint('[WatchHistory] 🗑️ Cleaned up legacy local database file: ${f1.path}');
      }
      final f2 = File('${directory.path}$name');
      if (await f2.exists()) {
        await f2.delete();
        debugPrint('[WatchHistory] 🗑️ Cleaned up legacy local database file: ${f2.path}');
      }
    }
  } catch (e) {
    debugPrint('[WatchHistory] Legacy database cleanup note: $e');
  }
}

/// Cloud-backed Movies Watch Controller (In-memory session state + Caffeine API / Supabase).
/// Watch history is no longer stored in local SQLite databases on Android.
class RecentlyWatchedMoviesController {
  static RecentlyWatchedMoviesController? _recentlyWatchedMoviesController;

  final List<RecentMovie> _inMemoryMovies = [];
  final Map<int, List<WatchEvent>> _inMemoryWatchEvents = {};

  String? get uid => _auth.currentUser?.id;
  GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Timestamp of the last successful cloud write. Used to debounce the API
  /// so progress saves during active playback don't hammer the server
  /// (periodic saves happen every 10 s). Completion writes always bypass this.
  DateTime? _lastCloudSync;

  RecentlyWatchedMoviesController._createInstance() {
    _cleanupLegacyDatabases();
  }

  factory RecentlyWatchedMoviesController() {
    _recentlyWatchedMoviesController ??=
        RecentlyWatchedMoviesController._createInstance();
    return _recentlyWatchedMoviesController!;
  }

  Future<List<RecentMovie>> getRecentMovieList() async {
    return List<RecentMovie>.from(_inMemoryMovies);
  }

  Future<int> insertMovie(RecentMovie rMovie) async {
    final idx = _inMemoryMovies.indexWhere((m) => m.id == rMovie.id);
    if (idx != -1) {
      _inMemoryMovies[idx] = rMovie;
    } else {
      _inMemoryMovies.insert(0, rMovie);
    }
    await addWatchedMovietoFirebase(rMovie);
    return 1;
  }

  Future<int> updateMovie(RecentMovie rMovie, int id) async {
    final idx = _inMemoryMovies.indexWhere((m) => m.id == id);
    if (idx != -1) {
      _inMemoryMovies[idx] = rMovie;
    } else {
      _inMemoryMovies.insert(0, rMovie);
    }
    await addWatchedMovietoFirebase(rMovie);
    return 1;
  }

  Future<int> deleteMovie(int id) async {
    _inMemoryMovies.removeWhere((m) => m.id == id);
    _inMemoryWatchEvents.remove(id);
    await removeMovieFromCloud(id);
    return 1;
  }

  Future<void> removeMovieFromCloud(int movieId) async {
    if (uid == null) return;
    try {
      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history');
      await http
          .delete(
            url,
            headers: {
              ...caffeineApiHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'media_type': 'movie',
              'media_id': movieId,
            }),
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[WatchHistory] ❌ API Delete Error: $e');
    }
  }

  Future<int> getCount() async {
    return _inMemoryMovies.length;
  }

  Future<bool> contain(int id) async {
    return _inMemoryMovies.any((m) => m.id == id);
  }

  /// Upserts movie by id (replaces existing, no duplicates) via Caffeine API.
  Future<void> addWatchedMovietoFirebase(RecentMovie rMovie) async {
    if (uid == null) return;
    try {
      final elapsed = rMovie.elapsed ?? 0;
      final remaining = rMovie.remaining ?? 0;
      final total = elapsed + remaining;
      final isFinished =
          remaining == 0 && elapsed > 0 || (total > 0 && (elapsed / total) >= 0.9);

      // Debounce: skip non-completion syncs that happened within the last 15 s.
      // This prevents hammering the API every 10 s during active playback.
      final now = DateTime.now();
      if (!isFinished &&
          _lastCloudSync != null &&
          now.difference(_lastCloudSync!).inSeconds < 15) {
        return;
      }
      _lastCloudSync = now;

      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history');

      final payload = {
        'session_id': rMovie.sessionId,
        'media_type': 'movie',
        'media_id': rMovie.id,
        'title': rMovie.title,
        'poster_path': rMovie.posterPath,
        'backdrop_path': rMovie.backdropPath,
        'elapsed_ms': elapsed,
        'duration_ms': total,
        'completed': isFinished,
        'started_at': rMovie.startedAt ?? rMovie.dateTime,
        'completed_at': isFinished ? (rMovie.dateTime ?? now.toIso8601String()) : null,
        'platform': Platform.isAndroid ? 'mobile_android' : (Platform.isIOS ? 'mobile_ios' : 'mobile'),
      };

      await http
          .post(
            url,
            headers: {
              ...caffeineApiHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[WatchHistory] ❌ API Sync Error: $e');
    }
  }

  Future<void> setWatchHistoryCollection() async {}

  Future<bool> checkIfDocExists(String docId) async {
    return true;
  }

  /// Inserts a new watch event (a "play") for [movieId] and fires the cloud sync.
  Future<void> insertWatchEvent(WatchEvent event, {
    required String? title,
    String? posterPath,
    String? backdropPath,
  }) async {
    final list = _inMemoryWatchEvents.putIfAbsent(event.mediaId, () => []);
    list.removeWhere((e) => e.eventId == event.eventId);
    list.insert(0, event);
    await addWatchEventToCloud(event,
        title: title, posterPath: posterPath, backdropPath: backdropPath);
  }

  Future<List<WatchEvent>> getWatchEvents(int movieId) async {
    return List<WatchEvent>.from(_inMemoryWatchEvents[movieId] ?? []);
  }

  Future<int> getWatchCount(int movieId) async {
    return _inMemoryWatchEvents[movieId]?.length ?? 0;
  }

  Future<void> deleteWatchEvent(String eventId) async {
    for (final list in _inMemoryWatchEvents.values) {
      list.removeWhere((e) => e.eventId == eventId);
    }
    await removeWatchEventFromCloud(eventId);
  }

  Future<void> deleteAllWatchEvents(int movieId) async {
    _inMemoryWatchEvents.remove(movieId);
  }

  /// Creates a new watch event on the Caffeine API.
  Future<void> addWatchEventToCloud(WatchEvent event, {
    required String? title,
    String? posterPath,
    String? backdropPath,
  }) async {
    if (uid == null) return;
    try {
      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history/watches');
      final payload = {
        'event_id': event.eventId,
        'media_type': 'movie',
        'media_id': event.mediaId,
        'title': title,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'watched_at': event.watchedAt.isEmpty ? null : event.watchedAt,
        'platform': Platform.isAndroid
            ? 'mobile_android'
            : (Platform.isIOS ? 'mobile_ios' : 'mobile'),
      };
      await http
          .post(
            url,
            headers: {
              ...caffeineApiHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[WatchHistory] ❌ Watch event API sync error: $e');
    }
  }

  /// Deletes a watch event on the Caffeine API.
  Future<void> removeWatchEventFromCloud(String eventId) async {
    if (uid == null) return;
    try {
      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history/watches/$eventId');
      await http
          .delete(url, headers: caffeineApiHeaders)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[WatchHistory] ❌ Watch event API delete error: $e');
    }
  }

  Future<void> clearAllMovies() async {
    _inMemoryMovies.clear();
    _inMemoryWatchEvents.clear();
    await _cleanupLegacyDatabases();
  }

  Future<void> replaceAllMovies(List<RecentMovie> movies) async {
    _inMemoryMovies
      ..clear()
      ..addAll(movies);
  }
}

/// Cloud-backed TV Episode Watch Controller (In-memory session state + Caffeine API / Supabase).
/// Watch history is no longer stored in local SQLite databases on Android.
class RecentlyWatchedEpisodeController {
  static RecentlyWatchedEpisodeController? _recentlyWatchedEpisodeController;

  final List<RecentEpisode> _inMemoryEpisodes = [];
  final Map<String, List<WatchEvent>> _inMemoryWatchEvents = {};

  String? get uid => _auth.currentUser?.id;
  GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Timestamp of the last successful cloud write. Used to debounce the API
  /// so progress saves during active playback don't hammer the server
  /// (periodic saves happen every 10 s). Completion writes always bypass this.
  DateTime? _lastCloudSync;

  RecentlyWatchedEpisodeController._createInstance() {
    _cleanupLegacyDatabases();
  }

  factory RecentlyWatchedEpisodeController() {
    _recentlyWatchedEpisodeController ??=
        RecentlyWatchedEpisodeController._createInstance();
    return _recentlyWatchedEpisodeController!;
  }

  Future<List<RecentEpisode>> getEpisodeList() async {
    return List<RecentEpisode>.from(_inMemoryEpisodes);
  }

  Future<int> insertTV(RecentEpisode rEpisode) async {
    final idx = _inMemoryEpisodes.indexWhere((e) =>
        (e.seriesId ?? e.id) == (rEpisode.seriesId ?? rEpisode.id) &&
        e.seasonNum == rEpisode.seasonNum &&
        e.episodeNum == rEpisode.episodeNum);
    if (idx != -1) {
      _inMemoryEpisodes[idx] = rEpisode;
    } else {
      _inMemoryEpisodes.insert(0, rEpisode);
    }
    await addWatchedTVtoFirebase(rEpisode);
    return 1;
  }

  Future<int> updateTV(
      RecentEpisode rEpisode, int id, int episodeNum, int seasonNum) async {
    return insertTV(rEpisode);
  }

  Future<int> deleteTV(int id, int episodeNum, int seasonNum) async {
    _inMemoryEpisodes.removeWhere((e) {
      final sId = e.seriesId ?? e.id;
      if (sId != id) return false;
      if (e.seasonNum != seasonNum) return false;
      if (e.episodeNum != episodeNum) return false;
      return true;
    });
    final key = '${id}_${seasonNum}_$episodeNum';
    _inMemoryWatchEvents.remove(key);
    await removeEpisodeFromCloud(id, episodeNum, seasonNum);
    return 1;
  }

  Future<void> removeEpisodeFromCloud(
      int epId, int episodeNum, int seasonNum) async {
    if (uid == null) return;
    try {
      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history');
      await http
          .delete(
            url,
            headers: {
              ...caffeineApiHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'media_type': 'tv',
              'media_id': epId,
              'season_num': seasonNum,
              'episode_num': episodeNum,
            }),
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[WatchHistory] ❌ API Delete Error: $e');
    }
  }

  Future<int> getCount() async {
    return _inMemoryEpisodes.length;
  }

  Future<bool> contain(int id) async {
    return _inMemoryEpisodes.any((e) => (e.seriesId ?? e.id) == id);
  }

  /// Upserts episode by id (replaces existing, no duplicates) via Caffeine API.
  Future<void> addWatchedTVtoFirebase(RecentEpisode rEpisode) async {
    if (uid == null) return;
    try {
      final elapsed = rEpisode.elapsed ?? 0;
      final remaining = rEpisode.remaining ?? 0;
      final total = elapsed + remaining;
      final isFinished =
          remaining == 0 && elapsed > 0 || (total > 0 && (elapsed / total) >= 0.9);

      // Debounce: skip non-completion syncs that happened within the last 15 s.
      final now = DateTime.now();
      if (!isFinished &&
          _lastCloudSync != null &&
          now.difference(_lastCloudSync!).inSeconds < 15) {
        return;
      }
      _lastCloudSync = now;

      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history');

      final payload = {
        'session_id': rEpisode.sessionId,
        'media_type': 'tv',
        'media_id': rEpisode.seriesId ?? rEpisode.id,
        'season_num': rEpisode.seasonNum,
        'episode_num': rEpisode.episodeNum,
        'title': rEpisode.seriesName,
        'episode_name': rEpisode.episodeName,
        'poster_path': rEpisode.posterPath,
        'backdrop_path': rEpisode.posterPath,
        'elapsed_ms': elapsed,
        'duration_ms': total,
        'completed': isFinished,
        'started_at': rEpisode.startedAt ?? rEpisode.dateTime,
        'completed_at': isFinished ? (rEpisode.dateTime ?? now.toIso8601String()) : null,
        'platform': Platform.isAndroid ? 'mobile_android' : (Platform.isIOS ? 'mobile_ios' : 'mobile'),
      };

      await http
          .post(
            url,
            headers: {
              ...caffeineApiHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[WatchHistory] ❌ API Sync Error: $e');
    }
  }

  Future<bool> checkIfDocExists(String docId) async {
    return true;
  }

  Future<void> setWatchHistoryCollection() async {}

  /// Inserts a new watch event (a "play") for the given series/season/episode.
  Future<void> insertWatchEvent(WatchEvent event, {
    required int? seriesId,
    required int? episodeId,
    required String? seriesName,
    String? episodeName,
    String? posterPath,
  }) async {
    final sId = seriesId ?? event.mediaId;
    final key = '${sId}_${event.seasonNum}_${event.episodeNum}';
    final list = _inMemoryWatchEvents.putIfAbsent(key, () => []);
    list.removeWhere((e) => e.eventId == event.eventId);
    list.insert(0, event);
    await addWatchEventToCloud(event,
        seriesId: seriesId,
        seriesName: seriesName,
        episodeName: episodeName,
        posterPath: posterPath);
  }

  Future<List<WatchEvent>> getWatchEvents(
      int seriesId, int seasonNum, int episodeNum) async {
    final key = '${seriesId}_${seasonNum}_$episodeNum';
    return List<WatchEvent>.from(_inMemoryWatchEvents[key] ?? []);
  }

  Future<int> getWatchCount(int seriesId, int seasonNum, int episodeNum) async {
    final key = '${seriesId}_${seasonNum}_$episodeNum';
    return _inMemoryWatchEvents[key]?.length ?? 0;
  }

  Future<void> deleteWatchEvent(String eventId) async {
    for (final list in _inMemoryWatchEvents.values) {
      list.removeWhere((e) => e.eventId == eventId);
    }
    await removeWatchEventFromCloud(eventId);
  }

  Future<void> deleteAllWatchEvents(
      int seriesId, int seasonNum, int episodeNum) async {
    final key = '${seriesId}_${seasonNum}_$episodeNum';
    _inMemoryWatchEvents.remove(key);
  }

  /// Creates a new watch event on the Caffeine API.
  Future<void> addWatchEventToCloud(WatchEvent event, {
    required int? seriesId,
    required String? seriesName,
    String? episodeName,
    String? posterPath,
  }) async {
    if (uid == null) return;
    try {
      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history/watches');
      final payload = {
        'event_id': event.eventId,
        'media_type': 'tv',
        'media_id': seriesId ?? event.mediaId,
        'season_num': event.seasonNum,
        'episode_num': event.episodeNum,
        'title': seriesName,
        'episode_name': episodeName,
        'poster_path': posterPath,
        'watched_at': event.watchedAt.isEmpty ? null : event.watchedAt,
        'platform': Platform.isAndroid
            ? 'mobile_android'
            : (Platform.isIOS ? 'mobile_ios' : 'mobile'),
      };
      await http
          .post(
            url,
            headers: {
              ...caffeineApiHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[WatchHistory] ❌ Watch event API sync error: $e');
    }
  }

  /// Deletes a watch event on the Caffeine API.
  Future<void> removeWatchEventFromCloud(String eventId) async {
    if (uid == null) return;
    try {
      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/history/watches/$eventId');
      await http
          .delete(url, headers: caffeineApiHeaders)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[WatchHistory] ❌ Watch event API delete error: $e');
    }
  }

  Future<void> clearAllEpisodes() async {
    _inMemoryEpisodes.clear();
    _inMemoryWatchEvents.clear();
    await _cleanupLegacyDatabases();
  }

  Future<void> replaceAllEpisodes(List<RecentEpisode> episodes) async {
    _inMemoryEpisodes
      ..clear()
      ..addAll(episodes);
  }
}
