import 'package:flutter/foundation.dart';

/// Environment selection — set at build/run time via --dart-define:
///
///   # Android emulator (default)
///   flutter run
///
///   # Physical device — pass your PC's LAN IP
///   flutter run --dart-define=LOCAL_API=http://192.168.1.20:5126
///
///   # Staging
///   flutter run --dart-define=APP_ENV=staging
///
///   # Production release
///   flutter build apk --dart-define=APP_ENV=prod
enum AppEnv { local, staging, prod }

class AppConfig {
  AppConfig._();

  static const String _envName =
      String.fromEnvironment('APP_ENV', defaultValue: 'local');

  /// Override the local API URL for physical device testing.
  static const String _localApiOverride =
      String.fromEnvironment('LOCAL_API', defaultValue: '');

  static AppEnv get env => AppEnv.values.byName(_envName);

  static String get apiBaseUrl {
    switch (env) {
      case AppEnv.local:
        if (_localApiOverride.isNotEmpty) return _localApiOverride;
        // 10.0.2.2 = Android emulator loopback to host machine
        return kIsWeb ? 'http://localhost:5126' : 'http://10.0.2.2:5126';
      case AppEnv.staging:
        // Current deployed test host (GCE). Swap for the AWS URL once that
        // migration happens.
        return 'https://gce-test.mapcars.uk';
      case AppEnv.prod:
        return 'https://api.mapcars.co.uk';
    }
  }

  static bool get isDev => env == AppEnv.local;

  /// App version for crash reports — pass at build time:
  /// `flutter build apk --dart-define=APP_VERSION=1.2.0`. Empty when unset,
  /// which just means the error log entry has no version against it.
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '');


  /// Hides dev-only chrome (the screen-stepper walk-through) for clean Play
  /// Store screenshots: `flutter run --dart-define=SCREENSHOT=true`.
  static const bool screenshotMode =
      bool.fromEnvironment('SCREENSHOT', defaultValue: false);

  /// Show the prototype screen-stepper only in dev and never in screenshot
  /// mode. Outside that the menu drawer falls back to the real driver menu.
  static bool get showDevNav => isDev && !screenshotMode;

  /// True in dev so OTP codes are displayed on-screen for testing.
  static bool get showDevOtp => isDev && kDebugMode;
}
