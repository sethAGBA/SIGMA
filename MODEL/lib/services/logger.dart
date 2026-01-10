import 'package:flutter/foundation.dart';

/// Minimal logger used across the app. Respects release mode to disable debug logs.
class AppLogger {
  static bool get isDebug => !kReleaseMode;

  static void debug(String message) {
    if (isDebug) {
      // ignore: avoid_print
      print('[DEBUG] $message');
    }
  }

  static void info(String message) {
    // ignore: avoid_print
    print('[INFO] $message');
  }

  static void error(String message) {
    // ignore: avoid_print
    print('[ERROR] $message');
  }
}
