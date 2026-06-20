import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_config.dart';

/// Typed access to environment configuration.
/// API base URL is resolved from AppConfig (--dart-define) with .env as override.
class Env {
  /// Base URL of the Mapcars .NET API.
  /// Priority: .env file > AppConfig (--dart-define=APP_ENV)
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? AppConfig.apiBaseUrl;

  /// Mapbox public token (pk....) for map rendering.
  static String get mapboxToken => dotenv.maybeGet('MAPBOX_TOKEN') ?? '';
}
