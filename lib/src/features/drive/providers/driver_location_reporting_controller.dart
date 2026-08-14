import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/driver_location_service.dart';

/// Streams the driver's GPS position and pushes it to the API every ~5s
/// (plus on every ~10m of movement) while online.
///
/// This is an app-level singleton, not owned by any screen's widget state —
/// it used to live in `_DriverHomeScreenState`, which Flutter disposes the
/// moment `context.go` replaces the route. That meant location reporting
/// (and, by extension, the driver's live GEO entry) silently stopped the
/// instant a driver left `/home` for *any* reason — accepting a trip,
/// checking earnings, viewing their profile — not just during an active trip.
/// Living here instead, it keeps running for as long as the driver is online,
/// independent of navigation.
class DriverLocationReportingController {
  DriverLocationReportingController(this._ref);

  final Ref _ref;
  StreamSubscription<Position>? _posSub;
  Timer? _pushTimer;
  Position? _lastPosition;
  String? _activeTripId;
  bool _online = false;

  /// Call when the driver goes online. Idempotent.
  void start() {
    if (_online) return;
    _online = true;

    _posSub = Geolocator.getPositionStream(
      locationSettings: _settings(),
    ).listen((pos) {
      _lastPosition = pos;
      _pushNow();
    });
    _pushTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pushNow());

    // An immediate fix rather than waiting for the stream's first update.
    Geolocator.getCurrentPosition().then((pos) {
      _lastPosition = pos;
      _pushNow();
    }).catchError((_) {});
  }

  /// The trip the driver is currently working (accepted → completed), if
  /// any — threaded onto every location push so the API can relay position to
  /// the rider tracking that trip. Set on accept, cleared once the trip ends.
  void setActiveTrip(String? tripId) => _activeTripId = tripId;

  /// Call when the driver goes offline.
  Future<void> stop() async {
    _online = false;
    _activeTripId = null;
    await _posSub?.cancel();
    _posSub = null;
    _pushTimer?.cancel();
    _pushTimer = null;
    // Best-effort removal from the live pool; ignore failures (going offline anyway).
    await _ref.read(driverLocationServiceProvider).goOffline().catchError((_) {});
  }

  void _pushNow() {
    final pos = _lastPosition;
    if (pos == null) return;
    // Fire-and-forget — a dropped location ping isn't worth surfacing.
    unawaited(_ref
        .read(driverLocationServiceProvider)
        .push(pos.latitude, pos.longitude, tripId: _activeTripId, heading: _heading(pos))
        .catchError((_) {}));
  }

  /// Location settings that keep fixes coming when the app isn't in front of
  /// the driver — which is the normal case: a working driver has the screen off
  /// in a cradle, or is in another app. Plain [LocationSettings] stops
  /// delivering within seconds of backgrounding on Android, so the driver's GEO
  /// entry goes stale after 60s and their car quietly vanishes from every
  /// rider's map while they are sitting there available.
  ///
  /// Android: an ongoing-notification foreground service (the platform's only
  /// sanctioned way to keep location alive). iOS: background location updates
  /// with the automotive activity type, and no automatic pausing.
  static LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Mapcars — you’re online',
          notificationText: 'Sharing your location so riders can find you.',
          notificationChannelName: 'Driver location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  /// Geolocator reports an invalid/unavailable heading as a negative or
  /// non-finite value depending on platform — treat both as "unknown" rather
  /// than sending garbage the API would otherwise have to validate away.
  double? _heading(Position pos) =>
      pos.heading.isFinite && pos.heading >= 0 ? pos.heading : null;
}

final driverLocationReportingProvider = Provider<DriverLocationReportingController>(
  (ref) => DriverLocationReportingController(ref),
);
