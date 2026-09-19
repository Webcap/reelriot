import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reelriot/utils/secure_local_storage.dart';

/// Central service for all authentication logic in Reelriot.
/// 
/// This service acts as the single source of truth for the user's 
/// authentication state and handles communication with Supabase.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  AuthService._internal();

  final _supabase = Supabase.instance.client;
  
  /// Override for testing purposes.
  @visibleForTesting
  Session? sessionOverride;

  /// Stream of authentication state changes.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// The currently active session, if any.
  Session? get currentSession => sessionOverride ?? _supabase.auth.currentSession;

  /// The currently authenticated user, if any.
  User? get currentUser => _supabase.auth.currentUser;

  /// Whether a user is currently signed in.
  bool get isSignedIn => currentSession != null;

  /// Reset the service to its initial state.
  @visibleForTesting
  void reset() {
    sessionOverride = null;
  }

  /// Initialize the auth state and attempt to recover a session.
  Future<void> initialize() async {
    debugPrint('[AuthService] 🚀 Initializing auth system...');
    
    // The Supabase.initialize in main.dart already triggers the initial 
    // load from storage via SecureLocalStorage.
    final session = _supabase.auth.currentSession;
    
    if (session != null) {
      debugPrint('[AuthService] ✅ Session recovered for: ${session.user.email}');
      // We might want to trigger a background refresh check here
      _verifySessionHealth();
    } else {
      debugPrint('[AuthService] ℹ️ No active session found on startup');
    }
  }

  /// Verifies the current session on app resume, refreshing it if it's near
  /// or past expiry. Call this from an `AppLifecycleState.resumed` hook so a
  /// long-backgrounded app doesn't sit on a stale token until something else
  /// happens to touch auth.
  Future<void> checkSessionOnResume() => _verifySessionHealth();

  /// Verifies if the current session is still valid and attempts a refresh if needed.
  /// This helps prevent the "daily sign-in" issue by proactively fixing stale sessions.
  Future<void> _verifySessionHealth() async {
    try {
      // If the token is near expiration, refresh it now.
      if (currentSession != null && currentSession!.expiresAt != null) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(currentSession!.expiresAt! * 1000);
        final now = DateTime.now();
        
        if (expiresAt.difference(now).inMinutes < 15) {
          debugPrint('[AuthService] 🔄 Session near expiry, refreshing...');
          await _supabase.auth.refreshSession();
        }
      }
    } catch (e) {
      debugPrint('[AuthService] ⚠️ Session health check failed: $e');
    }
  }

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
  }

  /// Sign in with Google OAuth.
  Future<bool> signInWithGoogle() async {
    try {
      return await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.reelriot.app://login-callback/',
      );
    } catch (e) {
      debugPrint('[AuthService] ❌ Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Sign out the current user and clear local session data.
  /// Defaults to [SignOutScope.local] so only this device session is terminated.
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    debugPrint('[AuthService] 🗑️ Signing out (scope: $scope)...');
    await _supabase.auth.signOut(scope: scope);
  }

  /// Manually refresh the current session.
  Future<Session?> refreshSession() async {
    final response = await _supabase.auth.refreshSession();
    return response.session;
  }
}
