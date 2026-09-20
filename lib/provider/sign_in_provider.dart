import 'package:reelriot/main.dart';
import 'package:reelriot/provider/bookmarks_provider.dart';
import 'package:reelriot/provider/ratings_provider.dart';
import 'package:reelriot/provider/recently_watched_provider.dart';
import 'package:reelriot/services/auth_service.dart';
import 'package:reelriot/services/analytics_service.dart';
import 'package:reelriot/controller/bookmark_database_controller.dart';
import 'package:reelriot/controller/recently_watched_database_controller.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:username_generator/username_generator.dart';
import 'package:reelriot/utils/routes/app_pages.dart';
import 'package:get/get.dart';
import 'dart:async';

class SignInProvider extends ChangeNotifier {
  final AppDependencyProvider? appDependencyProvider;
  final AuthService _authService;
  final _supabaseAuth = Supabase.instance.client.auth;
  var generator = UsernameGenerator();

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  bool _hasError = false;
  bool get hasError => _hasError;

  String? _errorCode;
  String? get errorCode => _errorCode;

  String? _provider;
  String? get provider => _provider;

  String? _uid;
  String? get uid => _uid;

  String? _email;
  String? get email => _email;

  String? _name;
  String? get name => _name ?? _username;

  String? _imageUrl;
  String? get imageUrl => _imageUrl;

  String? _username;
  String? get username => _username;

  int? _profileId;
  int? get profileId => _profileId;

  bool? _firstRun;
  bool? get firstRun => _firstRun;

  StreamSubscription<AuthState>? _authSubscription;

  SignInProvider({
    this.appDependencyProvider,
    AuthService? authService,
    this.authStream,
  }) : _authService = authService ?? AuthService.instance {
    _init();
  }

  /// The auth stream to subscribe to. If null, uses the [AuthService] stream.
  final Stream<AuthState>? authStream;

  void _init() {
    // Seed initial state from existing session
    final session = _authService.currentSession;
    if (session != null) {
      _applySession(session);
    }

    // Listen reactively to all future auth events.
    _authSubscription = (authStream ?? _authService.authStateChanges).listen(
      (data) {
        _onAuthEvent(data.event, data.session);
      },
      onError: (e) {
        debugPrint('[Auth] ⚠️ Auth stream error: $e');
      },
    );
  }

  Future<void> _onAuthEvent(AuthChangeEvent event, Session? session) async {
    debugPrint('[Auth] 🔄 Event: $event');

    switch (event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        if (session != null) {
          // Fetch fresh user to bypass stale session metadata
          try {
            final freshUser = await _supabaseAuth.getUser();
            if (freshUser.user != null) {
              _applyUser(freshUser.user!);
            } else {
              _applySession(session);
            }
          } catch (e) {
            debugPrint('[Auth] ⚠️ Could not fetch fresh user: $e');
            _applySession(session);
          }
          
          // Fetch or provision profile data (ensures new Google/OAuth users are fully provisioned)
          try {
            final exists = await checkuserExists();
            if (!exists && _uid != null) {
              await saveDatatoFirestore();
              final supabase = Supabase.instance.client;
              await supabase.from('bookmarks').upsert({
                'user_id': _uid,
                'movies': [],
                'tv_shows': [],
              });
              final generatedUsername = await createRandomUsername();
              await insertUsername(generatedUsername, _uid!);
              await supabase.from('profiles').update({
                'username': generatedUsername,
                'first_run': true,
              }).eq('id', _uid!);
            }
            await getUserDataFromFirestore(session.user.id);
          } catch (e) {
            debugPrint('[Auth] ⚠️ Could not setup or fetch profile: $e');
          }
          AnalyticsService.instance.identify(session.user.id);
        } else if (event == AuthChangeEvent.initialSession) {
           debugPrint('[Auth] ℹ️ Initial session was null');
        }
        break;

      case AuthChangeEvent.signedOut:
        debugPrint('[Auth] 🔑 Real sign-out detected');
        _handleSignOut();
        break;

      case AuthChangeEvent.passwordRecovery:
        break;

      // Supabase SDK may add new events in future versions — handle gracefully.
      // ignore: no_default_cases
      default:
        debugPrint('[Auth] 🔄 Unhandled event: $event');
    }
  }

  void _applySession(Session session) {
    _applyUser(session.user);
  }

  void _applyUser(User user) {
    _uid = user.id;
    _email = user.email;
    _name = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String?;
    _imageUrl = user.userMetadata?['avatar_url'] as String?;
    _profileId = int.tryParse(user.userMetadata?['avatar']?.toString() ??
        user.userMetadata?['profile_id']?.toString() ??
        '');
    _isSignedIn = true;
    notifyListeners();

    // Fetch extended profile in background (username, etc.)
    getUserDataFromFirestore(user.id).catchError((e) {
      debugPrint('[Auth] ⚠️ Could not fetch profile in background: $e');
    });

    // Check if user changed from previous session; if so, clear stale local bookmarks & watch history
    SharedPreferences.getInstance().then((s) {
      final lastBookmarkUid = s.getString('last_synced_bookmark_uid');
      if (lastBookmarkUid != null && lastBookmarkUid != user.id) {
        MovieDatabaseController().clearAll();
        TVDatabaseController().clearAll();
        s.remove('last_synced_bookmark_uid');
        try {
          BookmarksProvider.instance.clearAllLocalBookmarks();
        } catch (_) {}
      }
      final lastWatchUid = s.getString('last_synced_user_id');
      if (lastWatchUid != null && lastWatchUid != user.id) {
        RecentlyWatchedMoviesController().clearAllMovies();
        RecentlyWatchedEpisodeController().clearAllEpisodes();
        s.remove('last_synced_user_id');
        try {
          recentProvider.clearLocalData();
        } catch (_) {}
      }
      try {
        RatingsProvider.instance.fetchRatings();
      } catch (_) {}
    });
  }

  void _handleSignOut() async {
    _isSignedIn = false;
    _uid = null;
    _email = null;
    _name = null;
    _imageUrl = null;
    _profileId = null;
    _username = null;
    notifyListeners();
    await clearStoredData();

    AnalyticsService.instance.trackEvent('Signed Out');
    AnalyticsService.instance.reset();

    // Global redirect to login if we are signed out.
    // Use a small delay to ensure providers and state are fully updated.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isSignedIn) {
        Get.offAllNamed(Routes.login);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  Future<void> insertUsername(String username, String uid) async {
    await Supabase.instance.client
        .from('usernames')
        .insert({'username': username.toLowerCase(), 'user_id': uid});
  }

  Future<String> createRandomUsername() async {
    final supabase = Supabase.instance.client;
    String username = '';
    var available = false;

    while (!available) {
      username = generator.generateRandom();
      final res = await supabase
          .from('usernames')
          .select('username')
          .eq('username', username.toLowerCase())
          .limit(1);
      available = res.isEmpty;
    }

    return username;
  }

  Future<void> signInWithGoogle() async {
    _hasError = false;
    _errorCode = null;
    try {
      await _authService.signInWithGoogle();
      notifyListeners();
    } on AuthException catch (e) {
      _hasError = true;
      _errorCode = e.message;
      notifyListeners();
    }
  }

  Future<void> linkGoogleAccount() async {
    _hasError = false;
    _errorCode = null;
    try {
      await _authService.linkGoogleAccount();
      notifyListeners();
    } on AuthException catch (e) {
      _hasError = true;
      _errorCode = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<UserIdentity>> getUserIdentities() async {
    return await _authService.getUserIdentities();
  }

  Future<void> unlinkIdentity(UserIdentity identity) async {
    _hasError = false;
    _errorCode = null;
    try {
      await _authService.unlinkIdentity(identity);
      notifyListeners();
    } on AuthException catch (e) {
      _hasError = true;
      _errorCode = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign in with existing email/password and immediately link Google account.
  Future<void> signInAndLinkGoogle({
    required String email,
    required String password,
  }) async {
    _hasError = false;
    _errorCode = null;
    try {
      final res = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      if (res.session != null) {
        _applySession(res.session!);
        await _authService.linkGoogleAccount();
      }
    } on AuthException catch (e) {
      _hasError = true;
      _errorCode = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> getUserDataFromFirestore([String? uid]) async {
    final id = uid ?? _uid;
    if (id == null) return;

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', id)
          .limit(1);

      if (res.isNotEmpty) {
        final data = res[0];
        _uid = data['id']?.toString();
        _name = data['name'] as String?;
        _email = data['email'] as String?;
        _imageUrl = data['image_url'] as String?;
        final dbProfileId = int.tryParse(data['profile_id']?.toString() ?? '');
        if (dbProfileId != null) {
          _profileId = dbProfileId;
        }
        _provider = data['provider'] as String?;
        _firstRun = data['first_run'] as bool?;
        _username = data['username'] as String?;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Auth] ⚠️ Could not fetch profile (offline?): $e');
    }
  }

  Future<void> saveDatatoFirestore() async {
    if (_uid == null) return;

    await Supabase.instance.client.from('profiles').upsert({
      'id': _uid,
      'name': _name,
      'email': _email,
      'profile_id': 0,
      'image_url': _imageUrl ?? '',
      'provider': _provider ?? 'email',
      'verified': false,
      'is_subscribed': false,
      'first_run': false,
    });
    notifyListeners();
  }

  Future<bool> checkuserExists() async {
    if (_uid == null) return false;

    final res = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('id', _uid!)
        .limit(1);

    return res.isNotEmpty;
  }

  Future<bool> checkUsername(String username) async {
    final res = await Supabase.instance.client
        .from('usernames')
        .select('username')
        .eq('username', username.trim().toLowerCase())
        .limit(1);

    return res.isEmpty;
  }

  Future<void> userSignOut() async {
    await clearStoredData();
    await _authService.signOut();
    _handleSignOut();
  }

  Future<void> clearStoredData() async {
    final SharedPreferences s = await SharedPreferences.getInstance();
    await s.remove('name');
    await s.remove('email');
    await s.remove('uid');
    await s.remove('imageUrl');
    await s.remove('provider');
    await s.remove('username');
    await s.remove('firstRun');
    await s.remove('caffeine_recent_searches');
    await s.remove('adultStatus-v2');
    await s.remove('adultStatus');
    await s.remove('cached_movie_watch_mins');
    await s.remove('cached_tv_watch_mins');
    await s.remove('last_synced_user_id');
    await s.remove('last_synced_bookmark_uid');

    // Clear local watch data and bookmark SQLite tables
    try {
      await RecentlyWatchedMoviesController().clearAllMovies();
    } catch (_) {}
    try {
      await RecentlyWatchedEpisodeController().clearAllEpisodes();
    } catch (_) {}
    try {
      await MovieDatabaseController().clearAll();
    } catch (_) {}
    try {
      await TVDatabaseController().clearAll();
    } catch (_) {}

    // Clear in-memory providers so active screens don't retain previous user data
    try {
      await RecentProvider.instance.clearLocalData();
    } catch (_) {}

    try {
      await BookmarksProvider.instance.clearAllLocalBookmarks();
    } catch (_) {}

    try {
      RatingsProvider.instance.clearLocalRatings();
    } catch (_) {}

    // Flush Flutter in-memory image cache
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
  }
}
