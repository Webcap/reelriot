import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Unified service to control screen wake locks across mobile platforms.
///
/// Combines [WakelockPlus] with a direct Android native WindowManager flag
/// bridge to ensure screens stay awake on all Android devices (including Samsung
/// and Xiaomi devices with aggressive power-management behavior).
class WakelockService {
  static const MethodChannel _nativeChannel =
      MethodChannel('media.webcap.reelriot/screen_wake');

  static bool _isEnabled = false;

  /// Returns whether the wakelock has been requested by the application.
  static bool get isEnabled => _isEnabled;

  /// Enables the screen wakelock.
  static Future<void> enable() async {
    _isEnabled = true;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[WakelockService] WakelockPlus.enable failed: $e');
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('enable');
      } catch (e) {
        debugPrint('[WakelockService] Native screen_wake enable failed: $e');
      }
    }
  }

  /// Disables the screen wakelock.
  static Future<void> disable() async {
    _isEnabled = false;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[WakelockService] WakelockPlus.disable failed: $e');
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('disable');
      } catch (e) {
        debugPrint('[WakelockService] Native screen_wake disable failed: $e');
      }
    }
  }

  /// Re-asserts the wakelock if it is currently expected to be enabled.
  /// Call this when the app resumes from the background or during active playback.
  static Future<void> reassert() async {
    if (_isEnabled) {
      await enable();
    }
  }
}
