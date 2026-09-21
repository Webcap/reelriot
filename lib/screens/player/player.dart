import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reelriot/services/wakelock_service.dart';
import 'package:reelriot/utils/globals.dart';
import 'package:reelriot/controller/recently_watched_database_controller.dart';
import 'package:reelriot/models/sub_languages.dart';
import 'package:reelriot/models/external_subtitles.dart';
import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/functions/video_utils.dart';
import 'package:reelriot/models/movie_stream_metadata.dart';
import 'package:reelriot/models/provider_video_source.dart';
import 'package:reelriot/models/recently_watched.dart';
import 'package:reelriot/models/tv_stream_metadata.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/recently_watched_provider.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/screens/player/widgets/cast_bottom_sheet.dart';
import 'package:reelriot/services/analytics_service.dart';
import 'package:reelriot/services/cast_service.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/utils/globlal_methods.dart';
import 'package:reelriot/video_providers/provider_loader.dart';
import 'package:reelriot/video_providers/provider_names.dart';
import 'package:reelriot/widgets/common_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:reelriot/services/player/caffeine_player_controller.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/screens/player/widgets/language_picker_sheet.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/api/endpoints.dart';
import 'package:reelriot/screens/player/widgets/subtitle_selection_sheet.dart';
import 'package:reelriot/screens/player/widgets/glass_player_controls.dart';
import 'package:reelriot/utils/helpers/web_page.dart';

class Player extends StatefulWidget {
  final Map<String, String> sources;
  final List<CaffeinePlayerSubtitlesSource> subs;
  final List<Color> colors;
  final SettingsProvider settings;
  final MovieStreamMetadata? movieMetadata;
  final TVStreamMetadata? tvMetadata;
  final MediaType? mediaType;
  final String? subtitleStyle;
  final List<VideoProvider>? availableProviders;
  final String? currentProviderCode;
  final Map<String, String>? headers;

  const Player(
      {required this.sources,
      required this.subs,
      required this.colors,
      required this.settings,
      this.movieMetadata,
      this.tvMetadata,
      required this.mediaType,
      required this.subtitleStyle,
      this.availableProviders,
      this.currentProviderCode,
      this.headers,
      super.key});

  static bool isEmbedUrl(String url) {
    if (url.isEmpty) return false;
    final u = url.toLowerCase();
    if (u.contains('.m3u8') || u.contains('.mp4') || u.contains('.mkv') || u.contains('.webm')) {
      return false;
    }
    return u.contains('/embed') || u.contains('vixsrc.to/');
  }

  static String formatEmbedUrl(String rawUrl, int elapsedMs) {
    if (rawUrl.isEmpty) return rawUrl;
    final startSec = elapsedMs ~/ 1000;
    if (startSec <= 3) return rawUrl;
    final sep = rawUrl.contains('?') ? '&' : '?';
    return '$rawUrl${sep}startAt=$startSec&start=$startSec&time=$startSec&t=$startSec#t=$startSec';
  }

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  late CaffeinePlayerController _betterPlayerController;
  RecentlyWatchedMoviesController recentlyWatchedMoviesController =
      RecentlyWatchedMoviesController();
  RecentlyWatchedEpisodeController recentlyWatchedEpisodeController =
      RecentlyWatchedEpisodeController();
  int duration = 0;

  final GlobalKey _betterPlayerKey = GlobalKey();

  int totalMinutesWatched = 0;
  bool isVideoPaused = false;

  int playbackDurationInSeconds = 0;
  Timer? _durationTimer;
  // ignore: unused_field
  Timer? _resetTimer;

  late SettingsProvider settings;

  Map<String, String> _currentSources = {};
  List<CaffeinePlayerSubtitlesSource> _currentSubs = [];
  CaffeinePlayerSubtitlesSource? _currentSubtitleSource;
  bool _isSearchingSubtitles = false;
  final int _retryProviderIndex = 0;
  bool _isRetrying = false;

  /// Guards against writing a completion record more than once per session.
  bool _completionSaved = false;

  /// The most recent playback position reported by the player or the WebView
  /// JS bridge. Persists through seek-buffering gaps where
  /// [player.state.position] temporarily resets to zero.
  int _lastKnownPositionMs = 0;

  /// Returns the current playback position in milliseconds.
  /// Prefers active position, falling back to [_lastKnownPositionMs] so seeks
  /// and buffering gaps never cause position loss.
  int get _currentElapsedMs {
    if (_isEmbed) {
      if (_embedCurrentPositionMs > 0) {
        return _embedCurrentPositionMs;
      }
      final initialElapsed = widget.mediaType == MediaType.movie
          ? (widget.movieMetadata?.elapsed ?? 0)
          : (widget.tvMetadata?.elapsed ?? 0);
      final fallback = initialElapsed + (playbackDurationInSeconds * 1000);
      return fallback > _lastKnownPositionMs ? fallback : _lastKnownPositionMs;
    }

    final statePos = _betterPlayerController.isVideoInitialized() == true
        ? _betterPlayerController.player.state.position.inMilliseconds
        : 0;
    if (statePos > 0) {
      return statePos;
    }
    return _lastKnownPositionMs;
  }

  DateTime? _loadStartTime;
  DateTime? _bufferingStartTime;

  bool _isEmbed = false;
  bool _isEmbedFullscreen = false;
  String _embedUrl = '';
  int _embedCurrentPositionMs = 0;

  static bool isEmbedUrl(String url) {
    if (url.isEmpty) return false;
    final u = url.toLowerCase();
    if (u.contains('.m3u8') || u.contains('.mp4') || u.contains('.mkv') || u.contains('.webm')) {
      return false;
    }
    return u.contains('/embed') || u.contains('vixsrc.to/');
  }

  static String formatEmbedUrl(String rawUrl, int elapsedMs) {
    if (rawUrl.isEmpty) return rawUrl;
    final startSec = elapsedMs ~/ 1000;
    if (startSec <= 3) return rawUrl;
    final sep = rawUrl.contains('?') ? '&' : '?';
    return '$rawUrl${sep}startAt=$startSec&start=$startSec&time=$startSec&t=$startSec#t=$startSec';
  }

  Timer? _periodicSaveTimer;

  @override
  void initState() {
    settings = Provider.of<SettingsProvider>(context, listen: false);
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Periodic save every 10 seconds to minimise progress loss on hard-kill.
    _periodicSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      WakelockService.reassert();
      if (_betterPlayerController.isVideoInitialized() == true || _isEmbed) {
        final elapsed = _currentElapsedMs;
        if (widget.mediaType == MediaType.movie) {
          insertRecentMovieData(manualElapsed: elapsed);
        } else {
          insertRecentEpisodeData(manualElapsed: elapsed);
        }
      }
    });

    // Force landscape, hide status/nav bars, and keep screen on
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockService.enable();

    _currentSources = Map.from(widget.sources);
    _currentSubs = List.from(widget.subs);

    String keyToFind = widget.settings.defaultVideoResolution == 0
        ? 'auto'
        : widget.settings.defaultVideoResolution.toString();
    String? link;

    if (widget.sources.entries
        .where((entry) => entry.key == keyToFind)
        .isNotEmpty) {
      link = widget.sources.entries
          .where((entry) => entry.key == keyToFind)
          .map((entry) => entry.value)
          .first;
    } else if (widget.sources.isNotEmpty) {
      link = widget.sources.values.first;
    }

    _betterPlayerController = CaffeinePlayerController();
    // Set data source with initial seek if resuming
    final initialElapsed = widget.mediaType == MediaType.movie
        ? (widget.movieMetadata?.elapsed ?? 0)
        : (widget.tvMetadata?.elapsed ?? 0);

    if (link != null && isEmbedUrl(link)) {
      _isEmbed = true;
      _embedUrl = formatEmbedUrl(link, initialElapsed);
      startDurationTimer();
    } else {
      _isEmbed = false;
      _betterPlayerController.setDataSource(
        link ?? '',
        headers: widget.headers,
        subtitles: widget.subs,
        startAt: Duration(milliseconds: initialElapsed),
      );
    }

    _loadStartTime = DateTime.now();
    AnalyticsService.instance.trackQoSEvent('Playback Attempt', {
      'type': widget.mediaType == MediaType.movie ? 'movie' : 'tv_show',
      'id': widget.mediaType == MediaType.movie
          ? widget.movieMetadata?.movieId
          : widget.tvMetadata?.tvId,
      'name': widget.mediaType == MediaType.movie
          ? widget.movieMetadata?.movieName
          : widget.tvMetadata?.seriesName,
    });

    _betterPlayerController.addEventsListener((event) {
      if (event.type == CaffeinePlayerEventType.error) {
        _tryNextProvider();
      }
      if (event.type == CaffeinePlayerEventType.play) {
        startDurationTimer();
      }
      if (event.type == CaffeinePlayerEventType.pause) {
        pauseDurationTimer();
      }

      // Immediately track the user's seek target so _currentElapsedMs falls
      // back to the intended position during the seek-buffering gap (when
      // statePos is transiently 0), not the stale pre-rewind position.
      // We allow 0 here because seeking to the very beginning is intentional.
      if (event.type == CaffeinePlayerEventType.seek &&
          event.position != null) {
        _lastKnownPositionMs = event.position!.inMilliseconds;
      }

      // Update duration when it becomes available or changes
      if (mounted) {
        final newDuration = _betterPlayerController.duration.inMilliseconds;
        if (newDuration > 0 && newDuration != duration) {
          setState(() {
            duration = newDuration;
          });
        }
      }
    });

    // Completed event — intentionally NOT guarded by `mounted` because many OEM
    // Android ROMs unmount the widget before this fires at end of stream.
    _betterPlayerController.player.stream.completed.listen((completed) {
      if (completed) {
        debugPrint('[Player] 🏁 Stream completed event fired');
        if (!_completionSaved) {
          _completionSaved = true;
          _saveProgressOnExit(); // context-free, safe without mounted
          _invalidateWatchStatsCache();
        }
      }
    });

    // Position-based near-end completion trigger (≥ 92% watched).
    // Fires before the player reaches 100% so the record is saved even if the
    // user exits slightly early or the `completed` event is swallowed by the OS.
    _betterPlayerController.player.stream.position.listen((pos) {
      // Always track last known position (survives seek-buffering resets).
      if (pos.inMilliseconds > 0) {
        _lastKnownPositionMs = pos.inMilliseconds;
      }
      if (_completionSaved || _isEmbed) return;
      final dur = _betterPlayerController.player.state.duration;
      if (dur > Duration.zero) {
        final pct = pos.inMilliseconds / dur.inMilliseconds;
        if (pct >= 0.92) {
          _completionSaved = true;
          debugPrint('[Player] ✅ Near-end threshold reached (${(pct * 100).toStringAsFixed(1)}%) — marking completed');
          _saveProgressOnExit();
          _invalidateWatchStatsCache();
        }
      }
    });

    AnalyticsService.instance.trackEvent('Playback Started', {
      'type': widget.mediaType == MediaType.movie ? 'movie' : 'tv_show',
      'id': widget.mediaType == MediaType.movie
          ? widget.movieMetadata?.movieId
          : widget.tvMetadata?.tvId,
      'name': widget.mediaType == MediaType.movie
          ? widget.movieMetadata?.movieName
          : widget.tvMetadata?.seriesName,
      'episode': widget.tvMetadata?.episodeName,
      'season': widget.tvMetadata?.seasonNumber,
      'provider': widget.currentProviderCode,
    });

    // Auto-discover subtitles after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _autoDiscoverSubtitles();
      }
    });
  }

  Future<void> _autoDiscoverSubtitles() async {
    // MediaKit handle auto discovery differently (often via mpv)
    // For now, we manually loaded subs in initState.
  }

  void startDurationTimer() {
    if (_durationTimer == null) {
      _durationTimer =
          Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        setState(() {
          playbackDurationInSeconds++;
        });
      });

      _resetTimer = Timer.periodic(const Duration(seconds: 60), (Timer timer) {
        resetDurationTimer();
      });
    }
  }

  void pauseDurationTimer() {
    updateAndLogTotalStreamingDuration(playbackDurationInSeconds);
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void resetDurationTimer() {
    setState(() {
      playbackDurationInSeconds = 0;
    });
  }

  Future<void> _tryNextProvider() async {
    debugPrint('[Player] 🔄 _tryNextProvider called. Current: ${widget.currentProviderCode}');
    if (_isRetrying ||
        widget.availableProviders == null ||
        widget.currentProviderCode == null) {
      debugPrint('[Player] 🔄 Retry aborted: _isRetrying=$_isRetrying, availableProviders=${widget.availableProviders?.length}, currentProviderCode=${widget.currentProviderCode}');
      return;
    }

    final providers = widget.availableProviders!;
    final currentIndex =
        providers.indexWhere((p) => p.codeName == widget.currentProviderCode);
    if (currentIndex < 0 || currentIndex >= providers.length - 1) {
      return;
    }

    _isRetrying = true;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final language = settings.defaultAudioLanguage;
    final country = settings.defaultCountry;
    final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
    final route = appDep.fetchRoute.toLowerCase() == 'tmdb'
        ? StreamRoute.tmDB
        : StreamRoute.flixHQ;

    for (int i = currentIndex + 1; i < providers.length; i++) {
      ProviderLoaderResult result;
      if (widget.mediaType == MediaType.movie && widget.movieMetadata != null) {
        result = await ProviderLoader.loadMovieFromProvider(
          providerCode: providers[i].codeName,
          route: route,
          movieId: widget.movieMetadata!.movieId!,
          movieName: widget.movieMetadata!.movieName ?? '',
          releaseYear: widget.movieMetadata!.releaseYear?.toString(),
          flixApiUrl: appDep.flixApiUrl,
          language: language,
          country: country,
        );
      } else if (widget.mediaType == MediaType.tvShow &&
          widget.tvMetadata != null) {
        result = await ProviderLoader.loadTVFromProvider(
          providerCode: providers[i].codeName,
          route: route,
          tvId: widget.tvMetadata!.tvId!,
          seriesName: widget.tvMetadata!.seriesName ?? '',
          seasonNumber: widget.tvMetadata!.seasonNumber ?? 1,
          episodeNumber: widget.tvMetadata!.episodeNumber ?? 1,
          flixApiUrl: appDep.flixApiUrl,
          language: language,
          country: country,
        );
      } else {
        break;
      }

      if (result.success &&
          result.videoLinks != null &&
          result.videoLinks!.isNotEmpty &&
          mounted) {
        final newSources = VideoUtils.reverseVideoQualityMap(
          VideoUtils.convertVideoLinksToMap(result.videoLinks!),
        );
        _currentSources = newSources;
        if (result.subtitleLinks != null && result.subtitleLinks!.isNotEmpty) {
          _currentSubs = result.subtitleLinks!
              .map((s) => CaffeinePlayerSubtitlesSource(
                    name: s.language ?? 'Unknown',
                    urls: [s.url ?? ''],
                  ))
              .toList();
        }

        final keyToFind = widget.settings.defaultVideoResolution == 0
            ? 'auto'
            : widget.settings.defaultVideoResolution.toString();
        final link = newSources[keyToFind] ?? newSources.values.first;

        if (isEmbedUrl(link)) {
          _isEmbed = true;
          final elapsed = await _currentElapsedMilliseconds;
          _embedUrl = formatEmbedUrl(link, elapsed);
          if (_betterPlayerController.isPlaying()) {
            _betterPlayerController.pause();
          }
          if (mounted) setState(() {});
          break;
        } else {
          _isEmbed = false;
          final elapsed = await _currentElapsedMilliseconds;
          _betterPlayerController.setDataSource(
            link,
            headers: VideoUtils.extractHeaders(result.videoLinks!),
            subtitles: _currentSubs,
            startAt: Duration(milliseconds: elapsed),
          );
          _selectPreferredAudioTrack();
          if (mounted) setState(() {});
          break;
        }
      }
    }
    _isRetrying = false;
  }

  void _selectPreferredAudioTrack() {
    if (!mounted) return;
    final tracks = _betterPlayerController.audioTracks;
    if (tracks.isEmpty) {
      debugPrint('[Player] 🎧 No audio tracks available yet.');
      return;
    }

    final preferred = settings.defaultAudioLanguage.toLowerCase();
    debugPrint('[Player] 🎧 Attempting to select audio track: $preferred');

    for (final track in tracks) {
      final lang = track.language?.toLowerCase() ?? '';
      final label = track.title?.toLowerCase() ?? '';
      debugPrint('[Player]   - Track: lang="$lang", label="$label"');

      final isMatch = lang == preferred ||
          lang.startsWith(preferred) ||
          label.startsWith(preferred) ||
          label.contains(preferred) ||
          (preferred == 'en' && label.contains('english'));

      if (isMatch) {
        debugPrint('[Player] ✅ Match found! Selecting track: $label ($lang)');
        _betterPlayerController.setAudioTrack(track);
        return;
      }
    }

    // Secondary fallback: if default audio language was used but not found, try app language
    if (settings.defaultAudioLanguage != settings.appLanguage) {
      final fallback = settings.appLanguage.toLowerCase();
      debugPrint('[Player] 🎧 Fallback to app language: $fallback');
      for (final track in tracks) {
        final lang = track.language?.toLowerCase() ?? '';
        final label = track.title?.toLowerCase() ?? '';

        final isMatch = lang == fallback ||
            lang.startsWith(fallback) ||
            label.startsWith(fallback) ||
            label.contains(fallback) ||
            (fallback == 'en' && label.contains('english'));

        if (isMatch) {
          debugPrint(
              '[Player] ✅ Fallback match found! Selecting: $label ($lang)');
          _betterPlayerController.setAudioTrack(track);
          return;
        }
      }
    }
  }

  Future<void> insertRecentMovieData({int? manualElapsed}) async {
    if (!mounted || widget.movieMetadata == null) return;

    int elapsed = manualElapsed ?? _currentElapsedMs;

    if (elapsed < 3000 && _lastKnownPositionMs < 3000 && playbackDurationInSeconds < 3) return;

    final int playerDur = _isEmbed
        ? duration
        : _betterPlayerController.player.state.duration.inMilliseconds;
    final int effectiveDuration = playerDur > 0
        ? playerDur
        : (duration > 0 ? duration : 7200000); // 2h fallback
    int remaining = (effectiveDuration - elapsed).clamp(0, effectiveDuration);
    String dt = DateTime.now().toString();

    var isBookmarked = await recentlyWatchedMoviesController
        .contain(widget.movieMetadata!.movieId!);

    if (!mounted) return;
    final prv = Provider.of<RecentProvider>(context, listen: false);

    RecentMovie rMov = RecentMovie(
        dateTime: dt,
        elapsed: elapsed,
        id: widget.movieMetadata?.movieId ?? 0,
        posterPath: widget.movieMetadata?.posterPath ?? '',
        releaseYear: widget.movieMetadata?.releaseYear ?? 0,
        remaining: remaining,
        title: widget.movieMetadata?.movieName ?? '',
        backdropPath: widget.movieMetadata?.backdropPath ?? '');

    final bool isCompleted = (!_isEmbed && _betterPlayerController.player.state.completed) ||
        (effectiveDuration > 0 && (elapsed / effectiveDuration) >= 0.9) ||
        (effectiveDuration > 60000 && remaining <= 45000);

    if (!isBookmarked) {
      await prv.addMovie(rMov);
    } else {
      if (!isCompleted) {
        await prv.updateMovie(rMov, widget.movieMetadata!.movieId!);
      } else {
        final completed = RecentMovie(
          dateTime: dt,
          elapsed: effectiveDuration,
          id: widget.movieMetadata!.movieId!,
          posterPath: widget.movieMetadata!.posterPath ?? '',
          releaseYear: widget.movieMetadata!.releaseYear ?? 0,
          remaining: 0,
          title: widget.movieMetadata!.movieName ?? '',
          backdropPath: widget.movieMetadata!.backdropPath ?? '',
        );
        await prv.updateMovie(completed, widget.movieMetadata!.movieId!);
      }
    }
  }

  Future<void> insertRecentEpisodeData({int? manualElapsed}) async {
    if (!mounted || widget.tvMetadata == null) return;

    int elapsed = manualElapsed ?? _currentElapsedMs;

    if (elapsed < 3000 && _lastKnownPositionMs < 3000 && playbackDurationInSeconds < 3) return;

    final int playerDur = _isEmbed
        ? duration
        : _betterPlayerController.player.state.duration.inMilliseconds;
    final int effectiveDuration = playerDur > 0
        ? playerDur
        : (duration > 0 ? duration : 2700000); // 45m fallback
    int remaining = (effectiveDuration - elapsed).clamp(0, effectiveDuration);
    String dt = DateTime.now().toString();

    var isBookmarked = await recentlyWatchedEpisodeController
        .contain(widget.tvMetadata!.episodeId!);

    if (!mounted) return;
    final prv = Provider.of<RecentProvider>(context, listen: false);

    RecentEpisode rEpisode = RecentEpisode(
        dateTime: dt,
        elapsed: elapsed,
        id: widget.tvMetadata?.episodeId ?? 0,
        posterPath: widget.tvMetadata?.posterPath ?? '',
        remaining: remaining,
        seriesName: widget.tvMetadata?.seriesName ?? '',
        episodeName: widget.tvMetadata?.episodeName ?? '',
        episodeNum: widget.tvMetadata?.episodeNumber ?? 0,
        seasonNum: widget.tvMetadata?.seasonNumber ?? 0,
        seriesId: widget.tvMetadata?.tvId ?? 0);

    final bool isCompleted = (!_isEmbed && _betterPlayerController.player.state.completed) ||
        (effectiveDuration > 0 && (elapsed / effectiveDuration) >= 0.9) ||
        (effectiveDuration > 60000 && remaining <= 45000);

    if (!isBookmarked) {
      await prv.addEpisode(rEpisode);
    } else {
      if (!isCompleted) {
        await prv.updateEpisode(
            rEpisode,
            widget.tvMetadata!.episodeId!,
            widget.tvMetadata!.episodeNumber!,
            widget.tvMetadata!.seasonNumber!);
      } else {
        final completed = RecentEpisode(
            dateTime: dt,
            elapsed: effectiveDuration,
            id: widget.tvMetadata!.episodeId!,
            posterPath: widget.tvMetadata!.posterPath ?? '',
            remaining: 0,
            seriesName: widget.tvMetadata?.seriesName ?? '',
            episodeName: widget.tvMetadata?.episodeName ?? '',
            episodeNum: widget.tvMetadata?.episodeNumber ?? 0,
            seasonNum: widget.tvMetadata?.seasonNumber ?? 0,
            seriesId: widget.tvMetadata?.tvId ?? 0);
        await prv.updateEpisode(
            completed,
            widget.tvMetadata!.episodeId!,
            widget.tvMetadata!.episodeNumber!,
            widget.tvMetadata!.seasonNumber!);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final isInBackground = (state == AppLifecycleState.paused) ||
        (state == AppLifecycleState.inactive);
    final isResuming = state == AppLifecycleState.resumed;

    if (isInBackground) {
      if (_betterPlayerController.isVideoInitialized() == true || _isEmbed) {
        widget.mediaType == MediaType.movie
            ? insertRecentMovieData()
            : insertRecentEpisodeData();
      }
    } else if (isResuming) {
      WakelockService.enable();
      // If we are resuming and casting, check if the cast finished while away.
      // CastService is a ChangeNotifier, so it should trigger a build automatically
      // if it received a message while in the background (if proxy/socket stayed alive).
      // If not, it will update on next status message.
      setState(() {});
    }
  }

  /// Captures playback position synchronously, then writes directly to the
  /// local SQLite DB and Supabase without relying on context or Provider.
  /// Safe to call from dispose() because it doesn't use BuildContext.
  void _saveProgressOnExit() {
    try {
      // Capture all values synchronously BEFORE disposing the player.
      final bool initialized = _betterPlayerController.isVideoInitialized();
      if (!initialized && !_isEmbed) return;

      final int elapsed = _currentElapsedMs;

      // Don't save if we barely started (< 3s) — UNLESS we have a meaningful
      // last-known position (e.g., user seeked to credits and immediately exited).
      if (elapsed < 3000 && _lastKnownPositionMs < 3000 && playbackDurationInSeconds < 3) return;

      final bool playerCompleted =
          !_isEmbed && _betterPlayerController.player.state.completed;
      final int playerDur = _isEmbed
          ? duration
          : _betterPlayerController.player.state.duration.inMilliseconds;
      final int effectiveDuration = playerDur > 0
          ? playerDur
          : (duration > 0
              ? duration
              : (widget.mediaType == MediaType.movie ? 7200000 : 2700000));

      final double percentage = effectiveDuration > 0
          ? (elapsed / effectiveDuration) * 100
          : 0;
      final int remaining = playerCompleted
          ? 0
          : (effectiveDuration - elapsed).clamp(0, effectiveDuration);
      final String dt = DateTime.now().toString();
      final bool isCompleted = playerCompleted ||
          percentage >= 90 ||
          (effectiveDuration > 60000 && remaining <= 45000);

      if (widget.mediaType == MediaType.movie && widget.movieMetadata != null) {
        final meta = widget.movieMetadata!;
        final RecentMovie toSave = isCompleted
            ? RecentMovie(
                dateTime: dt,
                elapsed: effectiveDuration,
                id: meta.movieId ?? 0,
                posterPath: meta.posterPath ?? '',
                releaseYear: meta.releaseYear ?? 0,
                remaining: 0,
                title: meta.movieName ?? '',
                backdropPath: meta.backdropPath ?? '')
            : RecentMovie(
                dateTime: dt,
                elapsed: elapsed,
                id: meta.movieId ?? 0,
                posterPath: meta.posterPath ?? '',
                releaseYear: meta.releaseYear ?? 0,
                remaining: remaining,
                title: meta.movieName ?? '',
                backdropPath: meta.backdropPath ?? '');
        // Fire-and-forget: writes SQLite + Supabase independently of context.
        recentlyWatchedMoviesController.insertMovie(toSave);
        if (isCompleted) _invalidateWatchStatsCache();
      } else if (widget.tvMetadata != null) {
        final meta = widget.tvMetadata!;
        final RecentEpisode toSave = isCompleted
            ? RecentEpisode(
                dateTime: dt,
                elapsed: effectiveDuration,
                id: meta.episodeId ?? 0,
                posterPath: meta.posterPath ?? '',
                remaining: 0,
                seriesName: meta.seriesName ?? '',
                episodeName: meta.episodeName ?? '',
                episodeNum: meta.episodeNumber ?? 0,
                seasonNum: meta.seasonNumber ?? 0,
                seriesId: meta.tvId ?? 0)
            : RecentEpisode(
                dateTime: dt,
                elapsed: elapsed,
                id: meta.episodeId ?? 0,
                posterPath: meta.posterPath ?? '',
                remaining: remaining,
                seriesName: meta.seriesName ?? '',
                episodeName: meta.episodeName ?? '',
                episodeNum: meta.episodeNumber ?? 0,
                seasonNum: meta.seasonNumber ?? 0,
                seriesId: meta.tvId ?? 0);
        // Fire-and-forget: writes SQLite + Supabase independently of context.
        recentlyWatchedEpisodeController.insertTV(toSave);
        if (isCompleted) _invalidateWatchStatsCache();
      }
    } catch (e) {
      debugPrint('[Player] ⚠️ _saveProgressOnExit failed: $e');
    }
  }

  /// Clears the client-side SharedPreferences watch stats cache and fires a
  /// DELETE to the Caffeine API to bust the server-side Redis cache.
  /// Called only when playback is completed (>90% watched). Fire-and-forget.
  void _invalidateWatchStatsCache() {
    try {
      sharedPrefsSingleton.remove('cached_movie_watch_mins');
      sharedPrefsSingleton.remove('cached_tv_watch_mins');
      debugPrint('[Player] Completed: local watch stats cache cleared');

      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final base = caffeineApiUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/v1/user/$uid/watch-stats/cache');
      http
          .delete(url, headers: caffeineApiHeaders)
          .then((_) => debugPrint('[Player] Server watch stats cache invalidated'))
          .catchError(
            (Object e) => debugPrint('[Player] Server cache invalidation failed: $e'),
          );
    } catch (e) {
      debugPrint('[Player] _invalidateWatchStatsCache failed: $e');
    }
  }

  @override
  void dispose() {
    // Capture & persist position BEFORE disposing the player controller.
    // Must be synchronous — dispose() cannot await.
    _saveProgressOnExit();

    _durationTimer?.cancel();
    _resetTimer?.cancel();
    _periodicSaveTimer?.cancel();
    _betterPlayerController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    // Restore orientations, system overlays, and disable wakelock
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockService.disable();

    super.dispose();
  }

  String get _currentStreamUrl {
    final sources =
        _currentSources.isNotEmpty ? _currentSources : widget.sources;
    final keyToFind = widget.settings.defaultVideoResolution == 0
        ? 'auto'
        : widget.settings.defaultVideoResolution.toString();
    return sources.isNotEmpty
        ? (sources[keyToFind] ?? sources.values.first)
        : '';
  }

  String get _castTitle {
    if (widget.mediaType == MediaType.movie && widget.movieMetadata != null) {
      final year = widget.movieMetadata!.releaseYear;
      return '${widget.movieMetadata!.movieName ?? ''}${year != null ? ' ($year)' : ''}';
    }
    if (widget.tvMetadata != null) {
      return '${widget.tvMetadata!.seriesName ?? ''} – ${widget.tvMetadata!.episodeName ?? ''}';
    }
    return '';
  }

  bool _wasCasting = false;

  Future<void> _resumeFromCast(int positionSeconds) async {
    if (positionSeconds <= 0) {
      _betterPlayerController.play();
      return;
    }
    // Brief delay so the local player is visible and ready before seeking.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final initialized = _betterPlayerController.isVideoInitialized();
    if (initialized) {
      await _betterPlayerController.seekTo(Duration(seconds: positionSeconds));
    }
    _betterPlayerController.play();
  }

  String? get _castPosterUrl {
    final posterPath = widget.mediaType == MediaType.movie
        ? widget.movieMetadata?.posterPath
        : widget.tvMetadata?.posterPath;
    if (posterPath == null || posterPath.isEmpty) return null;
    return '$tmdbBaseImageUrl/w500$posterPath';
  }

  Future<int> get _currentElapsedMilliseconds async {
    return _currentElapsedMs;
  }

  void _openCastSheet() async {
    if (!mounted) return;
    if (_betterPlayerController.isPlaying()) {
      _betterPlayerController.pause();
    }
    final elapsed = await _currentElapsedMilliseconds;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CastBottomSheet(
        streamUrl: _currentStreamUrl,
        title: _castTitle,
        posterUrl: _castPosterUrl,
        elapsedSeconds: elapsed ~/ 1000,
        headers: widget.headers,
      ),
    );
  }

  Future<void> _openSubtitleSelectionSheet() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
        return SubtitleSelectionSheet(
          subtitles: _currentSubs,
          selectedSubtitle: _currentSubtitleSource,
          controller: _betterPlayerController,
          isLoading: _isSearchingSubtitles,
          onSubtitleSelected: (sub) {
            if (mounted) {
              setState(() {
                _currentSubtitleSource = sub;
              });
            }
            if (sub == null) {
              _betterPlayerController.player
                  .setSubtitleTrack(mk.SubtitleTrack.no());
            } else {
              _betterPlayerController.setSubtitleSource(sub);
            }
          },
          onSearchPressed: () async {
            final langCode = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const LanguagePickerSheet(),
            );

            if (langCode != null) {
              if (mounted) {
                setSheetState(() {
                  _isSearchingSubtitles = true;
                });
              }
              try {
                await _searchMoreSubtitles(langCode);
              } finally {
                if (mounted) {
                  setSheetState(() {
                    _isSearchingSubtitles = false;
                  });
                }
              }
            }
          },
        );
      }),
    );
  }

  Future<void> _searchMoreSubtitles(String langCode) async {
    try {
      final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
      final searchUrl = widget.mediaType == MediaType.movie
          ? Endpoints.searchExternalMovieSubtitles(
              widget.movieMetadata!.movieId!, langCode)
          : Endpoints.searchExternalEpisodeSubtitles(
              widget.tvMetadata!.tvId!,
              widget.tvMetadata!.episodeNumber!,
              widget.tvMetadata!.seasonNumber!,
              langCode,
            );

      final subtitleDataList = await getExternalSubtitle(
        searchUrl,
        appDep.opensubtitlesKey,
      );

      if (subtitleDataList.isNotEmpty) {
        final List<CaffeinePlayerSubtitlesSource> newExternalSubs = [];

        for (var subData in subtitleDataList) {
          final fileId = subData.attr?.files?.first.fileId;
          if (fileId != null) {
            final download = await downloadExternalSubtitle(
              Endpoints.externalSubtitleDownload(),
              fileId,
              appDep.opensubtitlesKey,
            );

            if (download.link != null) {
              final langName = supportedLanguages
                  .firstWhere((l) => l.languageCode == langCode,
                      orElse: () => SubLanguages(
                          languageName: langCode,
                          languageCode: langCode,
                          englishName: langCode))
                  .languageName;

              newExternalSubs.add(
                CaffeinePlayerSubtitlesSource(
                  name: "$langName ($fileId)",
                  urls: [download.link!],
                ),
              );
            }
          }
        }

        if (newExternalSubs.isNotEmpty) {
          final List<CaffeinePlayerSubtitlesSource> updatedSubs = [
            ..._currentSubs,
            ...newExternalSubs,
          ];

          // Filter duplicates
          final Map<String, CaffeinePlayerSubtitlesSource> uniqueSubs = {};
          for (var sub in updatedSubs) {
            uniqueSubs[sub.name!] = sub;
          }

          if (mounted) {
            setState(() {
              _currentSubs = uniqueSubs.values.toList();
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text("Found ${newExternalSubs.length} new subtitles")),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("No subtitles found for this language")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("No subtitles found for this language")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error searching subtitles: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error searching subtitles")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final castService = context.watch<CastService>();
    final isCasting = castService.isConnected;

    if (isCasting && !_wasCasting) {
      _wasCasting = true;
      if (_betterPlayerController.isPlaying()) {
        _betterPlayerController.pause();
      }
    } else if (!isCasting && _wasCasting) {
      _wasCasting = false;
      final resumePos = castService.lastCastPositionOnDisconnect ??
          castService.castPositionSeconds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resumeFromCast(resumePos);
      });
    }

    if (isCasting && castService.isMediaFinishedOnCast) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        debugPrint('[Player] 🏁 Cast media finished. Marking complete and returning.');
        
        // Use the total duration of the media to mark as 100% complete
        final castDurationMs = castService.totalMediaDurationSeconds * 1000;
        final finalElapsed = castDurationMs > 0 ? castDurationMs : duration;

        final navigator = Navigator.of(context);
        
        if (widget.mediaType == MediaType.movie) {
          await insertRecentMovieData(manualElapsed: finalElapsed);
        } else {
          await insertRecentEpisodeData(manualElapsed: finalElapsed);
        }

        castService.clearFinishedStatus();
        
        if (navigator.canPop()) {
          navigator.pop();
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navigator = Navigator.of(context);

        if (_betterPlayerController.isVideoInitialized() == true || _isEmbed) {
          final elapsed = _currentElapsedMs;

          if (widget.mediaType == MediaType.movie) {
            await insertRecentMovieData(manualElapsed: elapsed);
          } else {
            await insertRecentEpisodeData(manualElapsed: elapsed);
          }
        }

        if (navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_isEmbed)
              Positioned.fill(
                child: UrlWebPage(
                  url: _embedUrl,
                  embedded: true,
                  blockAds: true,
                  tryExtractHls: true,
                  startAtSeconds: ((widget.mediaType == MediaType.movie
                              ? (widget.movieMetadata?.elapsed ?? 0)
                              : (widget.tvMetadata?.elapsed ?? 0)) ~/
                          1000) +
                      playbackDurationInSeconds,
                  onProgressUpdate: (currSec, durSec) {
                    final posMs = (currSec * 1000).toInt();
                    _embedCurrentPositionMs = posMs;
                    _lastKnownPositionMs = posMs;
                    if (durSec > 0 && duration <= 0) {
                      duration = (durSec * 1000).toInt();
                    }
                  },
                  onFullscreenChanged: (isFull) {
                    setState(() {
                      _isEmbedFullscreen = isFull;
                    });
                  },
                  onHlsExtracted: (hls) async {
                    debugPrint('[Player] 🎯 HLS stream extracted from embed: $hls');
                    final elapsed = await _currentElapsedMilliseconds;
                    _isEmbed = false;
                    _betterPlayerController.setDataSource(
                      hls,
                      subtitles: _currentSubs,
                      startAt: Duration(milliseconds: elapsed),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              )
            else ...[
              Center(
                child: mkv.Video(
                  controller: _betterPlayerController.videoController,
                  controls: mkv.NoVideoControls,
                  wakelock: false,
                ),
              ),
              StreamBuilder<bool>(
                stream: _betterPlayerController.player.stream.buffering,
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            if (!_isEmbed)
              GlassPlayerControls(
                controller: _betterPlayerController,
                title: widget.mediaType == MediaType.movie
                    ? widget.movieMetadata?.movieName ?? ''
                    : widget.tvMetadata?.seriesName ?? '',
                subtitle: widget.mediaType == MediaType.tvShow
                    ? 'Season ${widget.tvMetadata?.seasonNumber} Episode ${widget.tvMetadata?.episodeNumber}'
                    : null,
                onBack: () => Navigator.of(context).pop(),
                onSubtitlePressed: _openSubtitleSelectionSheet,
                onResolutionPressed: () {}, // Resolution sheet not implemented yet
                onCastPressed: _openCastSheet,
              )
            else
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _isEmbedFullscreen ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: _isEmbedFullscreen,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            GlassIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.mediaType == MediaType.movie
                                    ? widget.movieMetadata?.movieName ?? ''
                                    : widget.tvMetadata?.seriesName ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (isCasting) _CastingOverlay(castService: castService),
          ],
        ),
      ),
    );
  }
}

/// Overlay displayed on the player while a Chromecast session is active.
class _CastingOverlay extends StatelessWidget {
  const _CastingOverlay({required this.castService});
  final CastService castService;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cast_connected, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              'Playing on',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              castService.connectedDeviceName ?? '',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            if (castService.nowPlayingTitle != null)
              Text(
                castService.nowPlayingTitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white60),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => castService.disconnect(),
              icon: const Icon(Icons.cast, color: Colors.white),
              label: const Text('Stop casting',
                  style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
