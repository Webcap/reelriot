import 'dart:async';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/utils/constant.dart' as constants;
import 'package:flutter/foundation.dart';
import 'package:reelriot/models/live_tv.dart';
import 'package:reelriot/models/espn_scoreboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../preferences/app_dependency_preferences.dart';
import '../services/ad_service.dart';
import '../models/ad.dart';
import '../utils/flavor_config.dart';
import '../utils/sports_helpers.dart';

import '../services/analytics_service.dart';

/// Holds app config from .env, SharedPreferences, and GET /config.
/// Prefer [loadFromPrefs] once at startup, then [fetchConfigFromApi] to overlay API config.
class AppDependencyProvider extends ChangeNotifier {
  final AppDependencies _prefs = AppDependencies();
  Map<String, dynamic> _featureFlags = {};
  final Set<String> _trackedFlags = {};

  /// Current evaluated feature flags for the user's platform/environment.
  Map<String, dynamic> get featureFlags => _featureFlags;

  set featureFlags(Map<String, dynamic> value) {
    bool hasChanged(String key) => _featureFlags[key] != value[key];
    final syncAds = hasChanged('ads_enabled') || hasChanged('global_ads') || hasChanged('enable_ads');
    
    _featureFlags = value;
    
    if (syncAds) {
      AdService.instance.updateEnabledStatus(enableADS);
    }
    
    notifyListeners();
  }

  Map<String, bool> _providerHealth = {};
  /// Cached provider health states (active vs degraded) for circuit-breaking
  Map<String, bool> get providerHealth => _providerHealth;

  set providerHealth(Map<String, bool> value) {
    _providerHealth = value;
    notifyListeners();
  }

  /// Check if a video provider is currently marked healthy/active. Defaults to true if unverified.
  bool isProviderHealthy(String codeName) {
    if (_providerHealth.containsKey(codeName)) {
      return _providerHealth[codeName] == true;
    }
    return true;
  }

  /// Returns the value of a feature flag, or a default value if not found.
  T getFlag<T>(String key, T defaultValue) {
    if (_featureFlags.containsKey(key)) {
      final raw = _featureFlags[key];
      
      // Check if it's the detailed format
      if (raw is Map<String, dynamic> && raw.containsKey('value')) {
        final val = raw['value'];
        
        // Track exposure for analytics if not already tracked in this session
        if (!_trackedFlags.contains(key)) {
          AnalyticsService.instance.trackEvent('Feature Flag Exposure', {
            'flag_key': key,
            'value': val,
            'variant': raw['variant'],
            'bucket': raw['bucket'],
            'reason': raw['reason'],
          });
          _trackedFlags.add(key);
        }

        if (val is T) return val;
        // Handle numeric to double/int conversion from JSON if needed.
        if (T == double && val is num) return val.toDouble() as T;
        if (T == int && val is num) return val.toInt() as T;
        if (T == bool && val is String) return (val.toLowerCase() == 'true') as T;
        
        try {
          return val as T;
        } catch (e) {
          return defaultValue;
        }
      }

      // Fallback for legacy simple format
      if (raw is T) return raw;
      if (T == double && raw is num) return raw.toDouble() as T;
      if (T == int && raw is num) return raw.toInt() as T;
    }
    return defaultValue;
  }


  /// Quick check for boolean feature flags.
  bool isFeatureEnabled(String key, {bool defaultValue = false}) {
    return getFlag<bool>(key, defaultValue);
  }

  /// Check if mobile live event chatroom is enabled
  bool get isMobileChatroomEnabled =>
      isFeatureEnabled('mobile_chatroom', defaultValue: true);

  // --- API / URLs ---
  String _caffeineAPIUrl = caffeineApiUrl;
  String get caffeineAPIURL {
    if (kDebugMode) {
      final env = constants.caffeineApiUrl.trim();
      if (env.isNotEmpty) {
        return env;
      }
    }
    return _caffeineAPIUrl;
  }

  set caffeineAPIURL(String value) {
    _caffeineAPIUrl = value;
    _prefs.setCaffeineAPIUrl(value);
    notifyListeners();
  }

  /// FlixAPI is merged into Caffeine API; same base URL.
  String get flixApiUrl => caffeineAPIURL;

  String _vidSrcApi = vidSrcApi;
  String get vidsrcapi => _vidSrcApi;
  set vidsrcapi(String value) {
    _vidSrcApi = value;
    _prefs.setvidSrcApi(value);
    notifyListeners();
  }

  String _newFlixHQUrl = '';
  String get newFlixHQUrl => _newFlixHQUrl;
  set newFlixHQUrl(String value) {
    _newFlixHQUrl = value;
    _prefs.setNewFlixHQUrl(value);
    notifyListeners();
  }

  // --- Streaming server options (Consumet / provider-specific) ---
  String _streamingServerFlixHQ = streamingServerFlixhq;
  String get streamingServerFlixHQ => _streamingServerFlixHQ;
  set streamingServerFlixHQ(String value) {
    _streamingServerFlixHQ = value;
    _prefs.setStreamServerFlixHQ(value);
    notifyListeners();
  }

  String _streamingServerDCVA = streamingServerDcva;
  String get streamingServerDCVA => _streamingServerDCVA;
  set streamingServerDCVA(String value) {
    _streamingServerDCVA = value;
    _prefs.setStreamServerDCVA(value);
    notifyListeners();
  }

  String _streamingServerZoro = constants.streamingServerZoro;
  String get streamingServerZoro => _streamingServerZoro;
  set streamingServerZoro(String value) {
    _streamingServerZoro = value;
    _prefs.setStreamServerZoro(value);
    notifyListeners();
  }

  String _newFlixhqServer = streamingServerNewFlixhq;
  String get newFlixhqServer => _newFlixhqServer;
  set newFlixhqServer(String value) {
    _newFlixhqServer = value;
    _prefs.setStreamServerNewFlixHQ(value);
    notifyListeners();
  }

  String _animekaiServer = 'vidcloud';
  String get animekaiServer => _animekaiServer;
  set animekaiServer(String value) {
    _animekaiServer = value;
    _prefs.setAnimekaiServer(value);
    notifyListeners();
  }

  String _hianimeServer = 'vidcloud';
  String get hianimeServer => _hianimeServer;
  set hianimeServer(String value) {
    _hianimeServer = value;
    _prefs.setHianimeServer(value);
    notifyListeners();
  }

  // --- Caffeine API / provider options ---
  String _vidSrcServer = 'vidsrcembed';
  String get vidSrcServer => _vidSrcServer;
  set vidSrcServer(String value) {
    _vidSrcServer = value;
    notifyListeners();
  }

  String _vidSrcToServer = 'vidplay';
  String get vidSrcToServer => _vidSrcToServer;
  set vidSrcToServer(String value) {
    _vidSrcToServer = value;
    notifyListeners();
  }

  String _tmdbProxy = '';
  String get tmdbProxy => _tmdbProxy;
  set tmdbProxy(String value) {
    _tmdbProxy = value;
    _prefs.setTmdbProxy(value);
    if (value.isNotEmpty) {
      constants.tmdbApiBaseUrl = value;
    }
    notifyListeners();
  }

  // --- App behavior / feature flags (from /config) ---
  String _fetchRoute = 'tmDB';
  String get fetchRoute => _fetchRoute;
  set fetchRoute(String value) {
    _fetchRoute = value;
    _prefs.setStreamRoute(value);
    notifyListeners();
  }

  String _opensubtitlesKey = openSubtitlesKey;
  String get opensubtitlesKey => _opensubtitlesKey;
  set opensubtitlesKey(String value) {
    _opensubtitlesKey = value;
    _prefs.setOpenSubKey(value);
    notifyListeners();
  }

  bool _useExternalSubtitles = false;
  bool get useExternalSubtitles => _useExternalSubtitles;
  set useExternalSubtitles(bool value) {
    _useExternalSubtitles = value;
    notifyListeners();
  }

  bool _displayWatchNowButton = true;
  bool get displayWatchNowButton => getFlag<bool>('enable_stream', _displayWatchNowButton);
  set displayWatchNowButton(bool value) {
    _displayWatchNowButton = value;
    notifyListeners();
  }

  bool _displayOTTDrawer = true;
  bool get displayOTTDrawer => getFlag<bool>('enable_live_sports', _displayOTTDrawer);
  set displayOTTDrawer(bool value) {
    _displayOTTDrawer = value;
    _prefs.setEnableOtt(value);
    notifyListeners();
  }

  List<String> _hiddenSportsRows = [];
  List<String> get hiddenSportsRows => _hiddenSportsRows;
  set hiddenSportsRows(List<String> value) {
    _hiddenSportsRows = value;
    notifyListeners();
  }

  /// Checks if a sport/league/title is hidden by admin config
  bool isSportRowHidden(String? sport, {String? league, String? title, EspnScoreboardGame? game}) {
    return isSportHidden(sport, _hiddenSportsRows, league: league, title: title, game: game);
  }

  /// Evaluates whether the active authenticated user has premium subscription status
  bool get isPremium {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;
      final appMeta = user.appMetadata;
      final userMeta = user.userMetadata;
      if (appMeta['is_premium'] == true) return true;
      if (userMeta != null && userMeta['is_premium'] == true) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _enableADS = true;
  bool get enableADS {
    if (isPremium) return false;
    if (getFlag<bool>('simulate_ads', false)) return true;
    if (!_enableADS) return false;
    if (getFlag<bool>('ads_enabled', true) == false) return false;
    if (getFlag<bool>('enable_ads', true) == false) return false;
    if (getFlag<bool>('global_ads', true) == false) return false;
    return true;
  }
  set enableADS(bool value) {
    if (_enableADS == value) return;
    _enableADS = value;
    AdService.instance.updateEnabledStatus(enableADS);
    notifyListeners();
  }

  /// Placement-specific ad toggles
  bool get enableHeroAds => enableADS && getFlag<bool>('enable_hero_ads', true);
  bool get enablePosterAds => enableADS && getFlag<bool>('enable_poster_ads', true);
  bool get enableBannerAds => enableADS && getFlag<bool>('enable_banner_ads', true);

  bool _enableOTTADS = true;
  bool get enableOTTADS => enableADS && getFlag<bool>('ott_ads_enabled', _enableOTTADS);
  set enableOTTADS(bool value) {
    _enableOTTADS = value;
    notifyListeners();
  }

  bool _enableAnonymousSignIn = false;
  bool get enableAnonymousSignIn => getFlag<bool>('enable_anonymous_signin', _enableAnonymousSignIn);
  set enableAnonymousSignIn(bool value) {
    _enableAnonymousSignIn = value;
    _prefs.setEnableAnonymousSignIn(value);
    notifyListeners();
  }

  bool _enableGoogleSignIn = false;
  bool get enableGoogleSignIn => getFlag<bool>(
        'enable_google_signin', 
        getFlag<bool>('enable_google_sign_in',
            getFlag<bool>('google_signin', _enableGoogleSignIn)));
  set enableGoogleSignIn(bool value) {
    _enableGoogleSignIn = value;
    _prefs.setEnableGoogleSignIn(value);
    notifyListeners();
  }

  String _mixpanelToken = '';
  String get mixpanelToken => _mixpanelToken;
  set mixpanelToken(String value) {
    if (_mixpanelToken == value) return;
    _mixpanelToken = value;
    _prefs.setMixpanelToken(value);
    notifyListeners();
  }

  // --- Update info (from /config) ---
  bool _isForcedUpdate = false;
  bool get isForcedUpdate => _isForcedUpdate;
  set isForcedUpdate(bool value) {
    _isForcedUpdate = value;
    notifyListeners();
  }

  String _latestVersion = '1.7.1';
  String get latestVersion => _latestVersion;
  set latestVersion(String value) {
    _latestVersion = value;
    notifyListeners();
  }

  String _updateDownloadUrl = '';
  String get updateDownloadUrl => _updateDownloadUrl;
  set updateDownloadUrl(String value) {
    _updateDownloadUrl = value;
    notifyListeners();
  }

  String _updateStoreUrl = '';
  String get updateStoreUrl => _updateStoreUrl;
  set updateStoreUrl(String value) {
    _updateStoreUrl = value;
    notifyListeners();
  }

  String _updateChangelog = '';
  String get updateChangelog => _updateChangelog;
  set updateChangelog(String value) {
    _updateChangelog = value;
    notifyListeners();
  }

  FeaturedEvent? _featuredEvent;
  FeaturedEvent? get featuredEvent => _featuredEvent;
  set featuredEvent(FeaturedEvent? value) {
    _featuredEvent = value;
    notifyListeners();
  }

  List<FeaturedEvent> _featuredEvents = [];
  List<FeaturedEvent> get featuredEvents => _featuredEvents;

  List<Ad> _initialAds = [];
  List<Ad> get initialAds {
    if (!enableADS) return [];
    final simulate = getFlag<bool>('simulate_ads', false);
    final isDev = kDebugMode || (FlavorConfig.instance.flavor == Flavor.dev);

    if (simulate && isDev) {
      return Ad.getSimulatedAds();
    }
    return _initialAds;
  }

  Future<void> fetchAds() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('sponsorships')
          .select()
          .eq('is_active', true)
          .order('priority', ascending: false);

      _initialAds = (response as List).map((e) => Ad.fromJson(e)).toList();
      debugPrint('Fetched ${_initialAds.length} native ads from Supabase');
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching native ads: $e');
    }
  }

  Future<void> fetchSportsStreams() async {
    try {
      final supabase = Supabase.instance.client;

      // Sync latest app_config (hidden_sports_rows & enable_live_sports) from Supabase
      try {
        final configRes = await supabase
            .from('app_config')
            .select('config')
            .eq('id', '00000000-0000-0000-0000-000000000001')
            .maybeSingle();
        if (configRes != null && configRes['config'] is Map) {
          final cfg = configRes['config'] as Map;
          if (cfg['hidden_sports_rows'] is List) {
            _hiddenSportsRows =
                (cfg['hidden_sports_rows'] as List).map((e) => e.toString()).toList();
          }
          if (cfg['enable_live_sports'] != null) {
            final v = cfg['enable_live_sports'];
            _displayOTTDrawer = v == true || v.toString().toLowerCase() == 'true';
            _prefs.setEnableOtt(_displayOTTDrawer);
          }
        }
      } catch (e) {
        debugPrint('Error syncing app_config for sports from Supabase: $e');
      }

      final response = await supabase
          .from('live_streams')
          .select()
          .eq('is_featured', true)
          .eq('is_hidden', false)
          .neq('video_url', '')
          .order('updated_at', ascending: false);

      final mapped = (response as List)
          .map((e) => FeaturedEvent(
                id: e['id']?.toString() ?? '',
                title: e['title'] ?? '',
                thumbnailUrl: e['poster_url']?.toString() ?? e['thumbnail_url']?.toString() ?? '',
                videoUrl: e['video_url'] ?? '',
                sport: e['sport'],
                referrer: e['referrer'],
              ))
          .toList();

      // Filter out events whose sport row is hidden
      _featuredEvents = mapped
          .where((e) => !isSportRowHidden(e.sport, title: e.title))
          .toList();

      if (_featuredEvents.isNotEmpty) {
        _featuredEvent = _featuredEvents.first;
      } else {
        _featuredEvent = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching sports streams from Supabase: $e');
    }
  }


  // --- Misc (stored, rarely used) ---
  String _caffieneLogo = 'default';
  String get caffieneLogo => _caffieneLogo;
  set caffieneLogo(String value) {
    _caffieneLogo = value;
    _prefs.setCaffieneUrl(value);
    notifyListeners();
  }

  String _anonymousId = '';
  String get anonymousId => _anonymousId;

  /// Load all persisted values from SharedPreferences in one go; call once at startup.
  /// Then call [fetchConfigFromApi] to overlay API config.
  Future<void> loadFromPrefs() async {
    _anonymousId = await _prefs.getAnonymousId();
    _caffeineAPIUrl = await _prefs.getFQURL();
    _vidSrcApi = await _prefs.getvidSrcApi();
    _opensubtitlesKey = await _prefs.getOpenSubtitlesKey();
    _streamingServerFlixHQ = await _prefs.getStreamServerFlixHQ();
    _streamingServerDCVA = await _prefs.getStreamServerDCVA();
    _streamingServerZoro = await _prefs.getStreamServerZoro();
    _fetchRoute = await _prefs.getStreamRoute();
    _newFlixHQUrl = await _prefs.getNewFlixHQUrl();
    _newFlixhqServer = await _prefs.getStreamServerNewFlixHQ();
    _animekaiServer = await _prefs.getAnimekaiServer();
    _hianimeServer = await _prefs.getHianimeServer();
    _tmdbProxy = await _prefs.getTmdbProxy();
    if (_tmdbProxy.isNotEmpty) {
      constants.tmdbApiBaseUrl = _tmdbProxy;
    }
    _caffieneLogo = await _prefs.getCaffieneLogo();
    _displayOTTDrawer = await _prefs.getEnableOtt();
    _enableAnonymousSignIn = await _prefs.getEnableAnonymousSignIn();
    _enableGoogleSignIn = await _prefs.getEnableGoogleSignIn();
    _mixpanelToken = await _prefs.getMixpanelToken();
    
    // Listen for auth transitions to toggle ads automatically for premium users
    try {
      _authSubscription?.cancel();
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        AdService.instance.updateEnabledStatus(enableADS);
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error subscribing to auth state change for ads: $e');
    }

    // Fetch native ads in background
    fetchAds();
    
    notifyListeners();
  }

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
