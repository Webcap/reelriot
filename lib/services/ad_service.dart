import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:startapp_sdk/startapp.dart';
import 'package:reelriot/services/analytics_service.dart';

class AdService extends ChangeNotifier {
  AdService._();
  static final AdService instance = AdService._();

  static const String startAppId = '207904245';

  bool _isInitialized = false;
  bool _isEnabled = true;
  StartAppSdk? _sdk;
  StartAppInterstitialAd? _interstitialAd;
  StartAppBannerAd? _bannerAd;
  bool _isInterstitialAdLoading = false;
  bool _isBannerAdLoading = false;
  Completer<void>? _interstitialCompleter;

  StartAppSdk? get sdk => _sdk;
  StartAppBannerAd? get bannerAd => _bannerAd;
  bool get isBannerAdLoading => _isBannerAdLoading;
  bool get isInterstitialAdLoading => _isInterstitialAdLoading;
  bool get isEnabled => _isEnabled;

  Future<void> initialize({StartAppSdk? sdk, bool enabled = true}) async {
    _isEnabled = enabled;
    if (_isInitialized) return;
    _sdk = sdk ?? StartAppSdk();
    
    // Explicitly disable test ads to ensure real ads are shown in production/release.
    // In debug mode, the platform SDK might still show test ads.
    await _sdk!.setTestAdsEnabled(false);

    _isInitialized = true;
    debugPrint('Start.io SDK Initialized with ID: $startAppId (Enabled: $_isEnabled)');
    
    if (_isEnabled) {
      _loadInterstitialAd();
      _loadBannerAd();
    }
  }

  void updateEnabledStatus(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    debugPrint('AdService: Ads enabled status updated to: $_isEnabled');
    if (_isEnabled) {
      _loadInterstitialAd();
      _loadBannerAd();
    } else {
      _bannerAd = null;
      _interstitialAd = null;
      notifyListeners();
    }
  }

  Future<StartAppBannerAd?> loadNewBannerAd() async {
    if (!_isEnabled || _sdk == null) {
      debugPrint('Start.io Banner Ad load skipped: enabled=$_isEnabled, sdk initialized=${_sdk != null}');
      return null;
    }
    try {
      final ad = await _sdk!.loadBannerAd(StartAppBannerType.BANNER);
      return ad;
    } catch (e) {
      debugPrint('Start.io Banner Ad failed to load: $e');
      return null;
    }
  }

  void _loadBannerAd() {
    if (!_isEnabled || _sdk == null || _isBannerAdLoading) {
      debugPrint(
          'Start.io Banner Ad skip load: enabled=$_isEnabled, sdk=${_sdk != null}, isLoading=$_isBannerAdLoading');
      return;
    }
    _isBannerAdLoading = true;
    debugPrint('Start.io Banner Ad loading...');

    _sdk!.loadBannerAd(StartAppBannerType.BANNER).then((ad) {
      _bannerAd = ad;
      _isBannerAdLoading = false;
      debugPrint('Start.io Banner Ad Loaded');
      notifyListeners();
    }).onError<StartAppException>((error, stackTrace) {
      debugPrint('Start.io Banner Ad failed to load: ${error.message}');
      _isBannerAdLoading = false;
      _bannerAd = null;
      notifyListeners();
      _retryLoadBanner();
    }).onError((error, stackTrace) {
      debugPrint('Start.io Banner Ad failed to load: $error');
      _isBannerAdLoading = false;
      _bannerAd = null;
      notifyListeners();
      _retryLoadBanner();
    });
  }

  void _retryLoadBanner() {
    Timer(const Duration(seconds: 30), () {
      debugPrint('Start.io Banner Ad retrying load...');
      _loadBannerAd();
    });
  }

  void _loadInterstitialAd() {
    if (!_isEnabled || _sdk == null || _isInterstitialAdLoading) {
      debugPrint(
          'Start.io Interstitial Ad skip load: enabled=$_isEnabled, sdk=${_sdk != null}, isLoading=$_isInterstitialAdLoading');
      return;
    }
    _isInterstitialAdLoading = true;
    debugPrint('Start.io Interstitial Ad loading...');

    _sdk!.loadInterstitialAd(
      onAdDisplayed: () {
        debugPrint('Start.io Interstitial Ad Displayed');
      },
      onAdNotDisplayed: () {
        debugPrint('Start.io Interstitial Ad not displayed');
        _interstitialAd = null;
        _interstitialCompleter?.complete();
        _interstitialCompleter = null;
        _loadInterstitialAd();
      },
      onAdClicked: () {
        debugPrint('Start.io Interstitial Ad Clicked');
        AnalyticsService.instance.trackEvent('ad_click', {
          'ad_id': 'startapp_interstitial',
          'title': 'StartApp Interstitial',
          'placement': 'interstitial',
          'format': 'interstitial',
          'timestamp': DateTime.now().toIso8601String(),
        });
      },
      onAdHidden: () {
        debugPrint('Start.io Interstitial Ad hidden');
        _interstitialAd = null;
        _interstitialCompleter?.complete();
        _interstitialCompleter = null;
        _loadInterstitialAd();
      },
      onAdImpression: () {
        debugPrint('Start.io Interstitial Ad Impression');
        AnalyticsService.instance.trackEvent('ad_impression', {
          'ad_id': 'startapp_interstitial',
          'title': 'StartApp Interstitial',
          'placement': 'interstitial',
          'format': 'interstitial',
          'timestamp': DateTime.now().toIso8601String(),
        });
      },
    ).then((ad) {
      _interstitialAd = ad;
      _isInterstitialAdLoading = false;
      debugPrint('Start.io Interstitial Ad Loaded');
      notifyListeners();
    }).onError<StartAppException>((error, stackTrace) {
      debugPrint('Start.io Interstitial Ad failed to load: ${error.message}');
      _isInterstitialAdLoading = false;
      _interstitialAd = null;
      notifyListeners();
      _retryLoadInterstitial();
    }).onError((error, stackTrace) {
      debugPrint('Start.io Interstitial Ad failed to load: $error');
      _isInterstitialAdLoading = false;
      _interstitialAd = null;
      notifyListeners();
      _retryLoadInterstitial();
    });
  }

  void _retryLoadInterstitial() {
    Timer(const Duration(seconds: 30), () {
      debugPrint('Start.io Interstitial Ad retrying load...');
      _loadInterstitialAd();
    });
  }

  Future<void> showInterstitialAd() async {
    if (!_isEnabled) {
      debugPrint('AdService: Interstitial ad skip show - ads are disabled.');
      return;
    }
    if (_interstitialAd == null) {
      debugPrint('Warning: Start.io Interstitial ad not loaded yet.');
      _loadInterstitialAd();
      return;
    }
    _interstitialCompleter = Completer<void>();
    _interstitialAd!.show();
    return _interstitialCompleter!.future;
  }
}
