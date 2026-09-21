import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:reelriot/utils/config.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  AnalyticsService._internal();

  Mixpanel? _mixpanel;
  bool _initialized = false;
  String? _currentToken;
  String? _appVersion;

  Future<void> initialize(String token) async {
    if (token.isEmpty) {
      debugPrint('Mixpanel token is empty, skipping initialization');
      return;
    }

    if (_initialized && _currentToken == token) return;

    try {
      _appVersion = currentAppVersion;

      _mixpanel = await Mixpanel.init(token, trackAutomaticEvents: true);
      _initialized = true;
      _currentToken = token;
      debugPrint('Mixpanel initialized successfully with token: ${token.substring(0, 6)}...');
      trackEvent('App Started');
    } catch (e) {
      debugPrint('Failed to initialize Mixpanel: $e');
    }
  }

  /// Track a general user engagement event
  void trackEvent(String eventName, [Map<String, dynamic>? properties]) {
    if (_initialized && _mixpanel != null) {
      try {
        _mixpanel!.track(eventName, properties: properties);
      } catch (e) {
        debugPrint('Failed to track Mixpanel event: $eventName: $e');
      }
    }
  }

  /// Track a technical Quality of Service (QoS) event
  void trackQoSEvent(String eventName, [Map<String, dynamic>? properties]) {
    debugPrint('Analytics [QoS]: $eventName ${properties ?? ""}');
    // QoS events are only printed to debug console now.
    // Previously they went to Supabase, but that was removed.
  }

  void identify(String userId) {
    if (!_initialized || _mixpanel == null) return;
    debugPrint('Mixpanel identify: $userId');
    _mixpanel!.identify(userId);
  }

  void setUserProfile(String key, dynamic value) {
    if (!_initialized || _mixpanel == null) return;
    debugPrint('Mixpanel setProfile: $key = $value');
    _mixpanel!.getPeople().set(key, value);
  }

  void reset() {
    if (!_initialized || _mixpanel == null) return;
    debugPrint('Mixpanel reset');
    _mixpanel!.reset();
  }
}
