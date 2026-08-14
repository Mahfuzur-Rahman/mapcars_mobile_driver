import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_config.dart';

/// Typed access to environment configuration.
/// API base URL is resolved from AppConfig (--dart-define) with .env as override.
class Env {
  /// Base URL of the Mapcars .NET API.
  /// Priority: .env file > AppConfig (--dart-define=APP_ENV)
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? AppConfig.apiBaseUrl;

  /// Google Maps key used for the Places + Directions web services (address
  /// autocomplete and routing). Needs the Places API, Directions API and
  /// Geocoding API enabled, and the key must allow web-service calls.
  /// Falls back to the native Android Maps key if a dedicated one isn't set.
  static String get googleMapsKey =>
      dotenv.maybeGet('GOOGLE_MAPS_KEY') ?? dotenv.maybeGet('MAPS_API_KEY') ?? '';

  /// OAuth 2.0 **Web** client ID (…apps.googleusercontent.com) passed to
  /// google_sign_in as `serverClientId` — it's what makes Google mint an ID
  /// token our API can verify. Must also be in the API's `Google:ClientId`
  /// audience list. Empty → the "Continue with Google" button still renders but
  /// reports that Google sign-in isn't set up.
  static String get googleServerClientId =>
      dotenv.maybeGet('GOOGLE_SERVER_CLIENT_ID') ?? '';

  /// Country codes (ISO 3166-1 alpha-2, comma-separated, e.g. "gb" or "gb,bd")
  /// that Places autocomplete is restricted to. Empty = search worldwide.
  /// Production should set "gb"; leave empty when testing outside the UK.
  static List<String> get placesCountries =>
      (dotenv.maybeGet('PLACES_COUNTRIES') ?? '')
          .split(',')
          .map((c) => c.trim().toLowerCase())
          .where((c) => c.isNotEmpty)
          .toList(growable: false);
}
