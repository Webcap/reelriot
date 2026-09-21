import 'dart:async';
import 'dart:io';
import 'package:media_kit/media_kit.dart';

import 'package:reelriot/caffiene_main.dart';
import 'package:reelriot/utils/flavor_config.dart';
import 'package:reelriot/utils/globals.dart';
import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/models/live_tv.dart';
import 'package:reelriot/models/translation.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/recently_watched_provider.dart';
import 'package:reelriot/singleton/sharedpreferences_singleton.dart';
import 'package:reelriot/utils/config_api.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/services/ad_service.dart';
import 'package:reelriot/services/analytics_service.dart';
import 'package:reelriot/utils/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reelriot/services/outage_service.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/utils/secure_local_storage.dart';
import 'package:reelriot/services/auth_service.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

bool isTablet(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  double threshold = 1000.0;
  return screenWidth > threshold;
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final String stack;

  const _ErrorScreen({required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              'Startup Error\n\n$error\n\n--- Stack ---\n$stack',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
      ),
    );
  }
}

late SettingsProvider settingsProvider;
late RecentProvider recentProvider;
late AppDependencyProvider appDependencyProvider;

Future<void> appInitialize() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Supabase MUST be initialized before RecentProvider - its controllers
  // access Supabase.instance.client in their constructors
  final supabaseAnonKey = dotenv.env['SUPABASE_ANNON_KEY']?.trim();
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw StateError(
      'SUPABASE_ANNON_KEY is missing in .env. '
      'Get it from Supabase Dashboard > Settings > API > anon public.',
    );
  }
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureLocalStorage(),
      ),
    );

    // Verify session recovery
    final authService = AuthService.instance;
    await authService.initialize();
    
    final session = authService.currentSession;
    final prefs = await SharedPreferences.getInstance();
    final hasUid = prefs.getString('uid') != null;

    if (session != null) {
      debugPrint(
          '[Main] 👤 Session recovered on startup for: ${session.user.email}');
    } else {
      if (hasUid) {
        debugPrint(
            '[Main] ⚠️ No Supabase session found, but legacy UID exists. Session persistence failure?');
      } else {
        debugPrint('[Main] 👤 No session found on startup (Clean start)');
      }
    }
  } catch (e) {
    throw StateError(
      'Supabase.initialize failed: $e\n\n'
      'Check SUPABASE_URL and SUPABASE_ANNON_KEY in .env. '
      'Anon key must be from Supabase Dashboard > Settings > API.',
    );
  }

  settingsProvider = SettingsProvider();
  recentProvider = RecentProvider();
  appDependencyProvider = AppDependencyProvider();
  await AdService.instance.initialize();
  await EasyLocalization.ensureInitialized();
  sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();
  try {
    await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  } catch (e) {
    // Already initialized (e.g. during integration test runs — safe to ignore).
    debugPrint('[Init] FlutterDownloader already initialized: $e');
  }
  await settingsProvider.getCurrentThemeMode();
// Material 3 removed
  await settingsProvider.getCurrentAdultMode();
  await settingsProvider.getCurrentImageQuality();
  await settingsProvider.getCurrentWatchCountry();
  await settingsProvider.getCurrentViewType();
  await settingsProvider.getSeekDuration();
  await settingsProvider.getMaxBufferDuration();
  await settingsProvider.getVideoResolution();
  await settingsProvider.getSubtitleSize();
  await settingsProvider.getForegroundSubtitleColor();
  await settingsProvider.getBackgroundSubtitleColor();
  await settingsProvider.getAppLanguage();
  await settingsProvider.getProviderPrecedence();
  await settingsProvider.getPlayerTimeStyle();
  await settingsProvider.getUseProxyMode();
  await settingsProvider.getSubtitleStyle();
  await settingsProvider.getDefaultAudioLanguage();

  // Load persistence (defaults)
  await appDependencyProvider.loadFromPrefs();
  // Fetch early config (inc RevenueCat keys)
  await fetchConfigFromApi(appDependencyProvider);
  await AnalyticsService.instance
      .initialize(appDependencyProvider.mixpanelToken);

  // Async cleanup of update files (non-blocking)
  unawaited(cleanupUpdateFiles());

  // Start API health monitoring
  OutageService.instance.start();
}

/// Non-critical fetches run after first frame to improve perceived startup.
void _deferredInit() {
  Future(() async {
    try {
      await recentProvider.syncFromCloud();
      await recentProvider.fetchMovies();
      await recentProvider.fetchEpisodes(
        isProxyEnabled: settingsProvider.enableProxy,
        proxyUrl: appDependencyProvider.tmdbProxy,
        language: settingsProvider.appLanguage,
      );

      // --- Featured Event Registration (Supabase Sync) ---
      await appDependencyProvider.fetchSportsStreams();
    } catch (e, st) {
      debugPrint('Deferred init error: $e\n$st');
    }
  });
}

void runAppWithFlavor() {
  FlutterError.onError = (details) {
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint(details.stack?.toString() ?? '');
    FlutterError.presentError(details);
  };

  runZonedGuarded(() async {
    try {
      await appInitialize();
      HttpOverrides.global = MyHttpOverrides();
      runApp(EasyLocalization(
        supportedLocales: Translation.all,
        path: 'assets/translations',
        fallbackLocale: Translation.all[0],
        startLocale: Locale(settingsProvider.appLanguage),
        child: Caffeine(
          settingsProvider: settingsProvider,
          recentProvider: recentProvider,
          appDependencyProvider: appDependencyProvider,
        ),
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) => _deferredInit());
    } catch (e, st) {
      final msg = 'STARTUP CRASH: $e\n\n$st';
      debugPrint(msg);
      // Removed stdout print to comply with lint
      runApp(_ErrorScreen(error: e.toString(), stack: st.toString()));
    }
  }, (error, stack) {
    if (error is AuthApiException &&
        error.code == 'refresh_token_already_used') {
      debugPrint(
          '[Auth] 🔑 Session stale (refresh token used elsewhere). User signed out naturally.');
      // Supabase 2.x handles clearing the session automatically when this error occurs
      return;
    }

    // Supabase token refresh failed due to network unavailability.
    // This is an expected transient error — do NOT treat as a crash or sign-out.
    if (error is AuthRetryableFetchException) {
      debugPrint(
          '[Auth] ⚠️ Token refresh network error (ignored): ${error.message}');
      return;
    }

    // Expected when Chromecast disconnects: proxy/cast socket writes fail.
    if (error is SocketException &&
        (error.message.contains('Broken pipe') ||
            error.osError?.errorCode == 32)) {
      debugPrint('[Cast] Connection closed: $error');
      return;
    }
    // Expected when video fails to load (e.g. no network, DNS, or source error).
    if (error is PlatformException &&
        (error.code == 'VideoError' ||
            (error.message?.contains('ExoPlaybackException') ?? false) ||
            (error.message?.contains('Source error') ?? false))) {
      debugPrint('[Video] Playback error: ${error.message ?? error.code}');
      return;
    }
    final msg = 'UNCAUGHT ERROR: $error\n\n$stack';
    debugPrint(msg);
    // Removed stdout print to comply with lint
    // Don't call runApp here - causes zone mismatch. Error already logged.
  });
}

void main() {
  FlavorConfig.initialize(
    flavor: Flavor.prod,
    appName: "Reelriot",
    baseUrl: 'https://caffeine.synqholdings.com/',
  );
  runAppWithFlavor();
}
