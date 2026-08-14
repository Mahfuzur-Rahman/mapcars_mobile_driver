import 'package:geolocator/geolocator.dart';

/// Thrown when the device location can't be read — carries a user-facing
/// [message] and whether opening OS settings would help the user recover.
class LocationException implements Exception {
  const LocationException(this.message, {this.openAppSettings = false});
  final String message;

  /// True when the fix is in the app's permission settings (permanently denied).
  final bool openAppSettings;

  @override
  String toString() => 'LocationException: $message';
}

/// Thin wrapper over `geolocator` that resolves the device's current position,
/// requesting permission and surfacing recoverable errors as [LocationException].
class LocationService {
  const LocationService();

  /// Returns the device's current position, prompting for permission if needed.
  /// Throws [LocationException] when the location can't be obtained.
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Location is turned off. Enable it in your device settings to see '
        'your position on the map.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Enable it for this app '
        'in Settings.',
        openAppSettings: true,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission is required to show your current position.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Opens the OS app-settings page (used to recover from a permanent denial).
  Future<void> openSettings() => Geolocator.openAppSettings();
}
