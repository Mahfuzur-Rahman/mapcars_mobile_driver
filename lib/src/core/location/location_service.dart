import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../permissions/permission_gate.dart';

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

  /// A cold GPS start can legitimately take a while, but it must not take
  /// forever: unbounded, a fix that never arrives leaves callers pinned to
  /// their loading state with no way back and no way to retry.
  static const _fixTimeout = Duration(seconds: 25);

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
      // Queued behind any other permission dialog. Android drops a request
      // raised while one is already on screen, and geolocator then never
      // completes this Future at all. See [PermissionGate].
      try {
        permission = await PermissionGate.request(Geolocator.requestPermission);
      } on TimeoutException {
        throw const LocationException(
          'Location permission is required to show your current position.',
        );
      }
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

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(_fixTimeout);
    } on TimeoutException {
      throw const LocationException(
        "Couldn't get a GPS fix. Move somewhere with a clearer view of the sky "
        'and try again.',
      );
    }
  }

  /// Whether location permission is currently held, without prompting for it.
  ///
  /// Map widgets gate `myLocationEnabled` on this rather than hardcoding `true`:
  /// the Android map silently skips enabling the blue dot when its platform view
  /// is created without permission, and never retries, because the Dart-side
  /// value never changed. It has to start false and flip true.
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Opens the OS app-settings page (used to recover from a permanent denial).
  Future<void> openSettings() => Geolocator.openAppSettings();
}
