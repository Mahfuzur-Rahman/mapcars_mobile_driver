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
        return 'https://api-staging.mapcars.co.uk';
      case AppEnv.prod:
        return 'https://api.mapcars.co.uk';
    }
  }

  static bool get isDev => env == AppEnv.local;

  /// True in dev so OTP codes are displayed on-screen for testing.
  static bool get showDevOtp => isDev && kDebugMode;
}
