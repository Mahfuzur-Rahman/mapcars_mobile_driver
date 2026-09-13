import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/geo/car_motion.dart';
import '../../../../core/geo/geo_math.dart';
import '../../../../core/geo/route_path.dart';
import '../../../../core/permissions/permission_gate.dart';
import '../../../../core/theme/brand.dart';
import '../../../navigate/models/directions_result.dart';
import '../../../navigate/services/maps_service.dart';
import '../../services/car_icon.dart';

/// Live route metrics, recomputed on every GPS fix and handed to the screen so
/// its sheet can show a real ETA instead of a hard-coded one.
class RouteProgress {
  const RouteProgress({
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.totalMeters,
  });

  /// Straight distance still to cover along the route.
  final double remainingMeters;

  /// Estimated seconds left, scaled from the fetched route's duration.
  final int remainingSeconds;

  /// The route's full length, as fetched — the denominator for [fraction].
  final double totalMeters;

  /// 0 → just started, 1 → arrived. Clamped, so a driver who wanders off-route
  /// past the destination doesn't drive the progress bar past full.
  double get fraction => totalMeters <= 0
      ? 0
      : (1 - (remainingMeters / totalMeters)).clamp(0.0, 1.0);

  /// "1.2 mi" / "850 ft" — UK ride-hail convention is imperial for distance.
  String get distanceLabel {
    final miles = remainingMeters / 1609.344;
    if (miles < 0.2) return '${(remainingMeters * 3.28084).round()} ft';
    return '${miles.toStringAsFixed(1)} mi';
  }

  /// "4 min" — never "0 min", which reads as broken while you're still moving.
  String get etaLabel {
    final minutes = (remainingSeconds / 60).round();
    return minutes < 1 ? '< 1 min' : '$minutes min';
  }

  /// Clock time of arrival, e.g. "4:38".
  String get arrivalLabel {
    final at = DateTime.now().add(Duration(seconds: remainingSeconds));
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '$hour:${at.minute.toString().padLeft(2, '0')}';
  }
}

/// A real Google map showing the driver's live position, the route to
/// [destination], and how far is left — the working replacement for the
/// decorative `MapBackground` the driving screens used to sit on.
///
/// Route handling is deliberately frugal: the Directions API is billed per call,
/// so the route is fetched once and then only re-fetched after the driver has
/// moved [_rerouteMeters] from where it was last computed (and no sooner than
/// [_rerouteMinGap]). Between fetches the remaining distance/ETA are derived
/// locally by projecting the driver onto the fetched polyline, which is what
/// makes the numbers tick down smoothly without a request per second.
class LiveRouteMap extends ConsumerStatefulWidget {
  const LiveRouteMap({
    super.key,
    required this.destination,
    this.destinationLabel = 'Destination',
    this.isPickup = false,
    this.onProgress,
  });

  final LatLng destination;
  final String destinationLabel;

  /// Pickup legs are drawn green (go get the rider), drop-off legs blue.
  final bool isPickup;

  /// Called on every GPS fix with fresh route metrics.
  final ValueChanged<RouteProgress>? onProgress;

  @override
  ConsumerState<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends ConsumerState<LiveRouteMap> {
  /// How far the driver must move before the route is re-fetched from Google.
  static const _rerouteMeters = 150.0;

  /// …and the minimum wall-clock gap between fetches, so crawling through
  /// stop-start traffic can't trigger a burst of calls.
  static const _rerouteMinGap = Duration(seconds: 25);

  static const _fallback =
      CameraPosition(target: LatLng(51.5074, -0.1278), zoom: 11);

  GoogleMapController? _controller;
  StreamSubscription<Position>? _posSub;

  /// Where the car is *drawn*. The driver's own fixes arrive on movement
  /// rather than on a clock, so without this the car jumped from fix to fix —
  /// the one map in the product that had no interpolation at all.
  final CarMotion _motion = CarMotion();

  /// Repaints while the car is gliding. ~12fps, the same cadence the rider's
  /// map runs at, and stopped whenever nothing is moving.
  static const _frameInterval = Duration(milliseconds: 80);
  Timer? _ticker;

  BitmapDescriptor? _carIcon;

  DirectionsResult? _route;

  /// [_route]'s polyline, prepared for projection and travel along.
  RoutePath? _path;
  LatLng? _routeFrom;
  DateTime? _routeFetchedAt;
  bool _fetchingRoute = false;
  String? _routeError;

  /// Camera sticks to the driver until they pan the map themselves, then a
  /// "Re-centre" pill brings it back — panning ahead to check a junction
  /// shouldn't be fought by the follow camera.
  bool _following = true;
  bool _selfMove = false;

  @override
  void initState() {
    super.initState();
    // Pearl: the route polyline below this marker is green on the pickup leg
    // and blue on the trip leg, so the car needs a body colour that contrasts
    // with both rather than matching one of them.
    drawCarIcon(Brand.carPearl).then((icon) {
      if (mounted) setState(() => _carIcon = icon);
    });
    _startTracking();
    _ticker = Timer.periodic(_frameInterval, (_) => _onFrame());
  }

  @override
  void didUpdateWidget(LiveRouteMap old) {
    super.didUpdateWidget(old);
    // A new destination (pickup → drop-off) invalidates the whole route.
    if (old.destination != widget.destination) {
      _route = null;
      _path = null;
      _motion.route = null;
      _routeFrom = null;
      _routeFetchedAt = null;
      final me = _motion.position;
      if (me != null) unawaited(_fetchRoute(me));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _posSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Repaint only while the car is actually gliding, so a driver waiting at a
  /// pickup isn't rebuilding the map twelve times a second for nothing.
  void _onFrame() {
    if (!mounted) return;
    if (_motion.isMoving) setState(() {});
  }

  Future<void> _startTracking() async {
    // Permission is already granted in practice (the driver went online, which
    // starts location reporting), but a cold deep-link into this screen might
    // not have asked yet.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Queued behind any other permission dialog — Android drops a request
      // raised while one is already on screen, and geolocator then never
      // completes this Future at all. See [PermissionGate].
      try {
        permission = await PermissionGate.request(Geolocator.requestPermission);
      } on TimeoutException {
        return;
      }
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final first = await Geolocator.getCurrentPosition();
      _onFix(first);
    } catch (_) {
      // No immediate fix — the stream below will deliver one shortly.
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen(_onFix);
  }

  void _onFix(Position pos) {
    if (!mounted) return;
    final me = LatLng(pos.latitude, pos.longitude);

    // Hold the last known bearing when the device can't supply one, rather
    // than snapping the car back to north while it's clearly still moving.
    _motion.onFix(
      me,
      reportedHeading:
          pos.heading.isFinite && pos.heading >= 0 ? pos.heading : null,
    );
    setState(() {});

    // The progress numbers, the camera and the reroute check all key off the
    // real fix, not the drawn position — only the marker is interpolated.
    _emitProgress(me);
    if (_following) _followCamera(_motion.position ?? me);

    if (_shouldRefetch(me)) unawaited(_fetchRoute(me));
  }

  bool _shouldRefetch(LatLng me) {
    if (_fetchingRoute) return false;
    if (_route == null || _routeFrom == null) return true;

    final since = _routeFetchedAt;
    if (since != null && DateTime.now().difference(since) < _rerouteMinGap) {
      return false;
    }
    return metersBetween(me, _routeFrom!) >= _rerouteMeters;
  }

  Future<void> _fetchRoute(LatLng from) async {
    _fetchingRoute = true;
    try {
      final route = await ref
          .read(googleMapsServiceProvider)
          .directions(origin: from, destination: widget.destination);
      if (!mounted) return;
      setState(() {
        _route = route;
        _path = RoutePath(route.points);
        // Hand the car the new line to follow. CarMotion rebases onto where it
        // is currently drawn, so a refetch never teleports it.
        _motion.route = _path;
        _routeFrom = from;
        _routeFetchedAt = DateTime.now();
        _routeError = null;
      });
      _emitProgress(from);
    } on MapsServiceException catch (e) {
      if (!mounted) return;
      // Keep any previously fetched route on screen — a stale line beats a
      // blank map — and only surface the message when we have nothing at all.
      setState(() => _routeError = _route == null ? e.message : null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _routeError =
          _route == null ? "Couldn't load the route. Retrying…" : null);
    } finally {
      _fetchingRoute = false;
    }
  }

  /// Projects [me] onto the fetched polyline and reports what's left. Falls back
  /// to straight-line distance (× a typical road factor) until a route arrives,
  /// so the sheet shows a sane number from the first fix rather than a dash.
  void _emitProgress(LatLng me) {
    final onProgress = widget.onProgress;
    if (onProgress == null) return;

    final route = _route;
    final path = _path;
    final RouteProgress progress;
    if (route == null || path == null || !path.isUsable) {
      final straight = metersBetween(me, widget.destination);
      final meters = straight * 1.35;
      progress = RouteProgress(
        remainingMeters: meters,
        // 18 mph is a realistic urban average, and the same figure the customer
        // app estimates with when it has no previewed route.
        remainingSeconds: (meters / 1609.344 / 18.0 * 3600).round(),
        totalMeters: meters,
      );
    } else {
      final remaining = path.remainingFrom(
          path.project(me, nearAlongMeters: _motion.alongMeters).alongMeters);
      final total = route.distanceMeters.toDouble();
      final ratio = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);

      progress = RouteProgress(
        remainingMeters: remaining,
        remainingSeconds: (route.durationSeconds * ratio).round(),
        totalMeters: total,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onProgress(progress);
    });
  }

  Future<void> _followCamera(LatLng me) async {
    final controller = _controller;
    if (controller == null) return;
    _selfMove = true;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
            target: me, zoom: 16.5, bearing: _motion.heading, tilt: 45),
      ),
    );
    _selfMove = false;
  }

  /// The route ahead only — the leg already driven is dropped so the line
  /// shrinks toward the destination as the trip progresses.
  List<LatLng> _polylineAhead() {
    final path = _path;
    final me = _motion.position;
    if (path == null || !path.isUsable) return const [];
    if (me == null) return path.points;

    // On the route, the line starts exactly under the car. Off it (a wrong
    // turn, or a route gone stale), join the car to the road so the two do not
    // read as unrelated.
    final along = _motion.alongMeters;
    if (along != null) return path.pointsFrom(along);
    return [me, ...path.pointsFrom(path.project(me).alongMeters)];
  }

  @override
  Widget build(BuildContext context) {
    final me = _motion.position;
    final ahead = _polylineAhead();
    final legColour = widget.isPickup ? Brand.green : Brand.blue;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: me == null
                ? _fallback
                : CameraPosition(target: me, zoom: 16.5),
            // The car marker below *is* the driver, so the default blue dot
            // would just draw a second "you" on top of it.
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (c) {
              _controller = c;
              if (me != null) _followCamera(me);
            },
            onCameraMoveStarted: () {
              if (!_selfMove && _following) setState(() => _following = false);
            },
            markers: {
              if (me != null)
                Marker(
                  markerId: const MarkerId('me'),
                  position: me,
                  rotation: _motion.heading,
                  anchor: const Offset(0.5, 0.5),
                  flat: true,
                  // Keep the car above the destination pin.
                  zIndexInt: 2,
                  icon: _carIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure),
                ),
              Marker(
                markerId: const MarkerId('destination'),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(widget.isPickup
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueAzure),
                infoWindow: InfoWindow(
                  title: widget.isPickup ? 'Pickup' : 'Drop-off',
                  snippet: widget.destinationLabel,
                ),
              ),
            },
            polylines: {
              if (ahead.length >= 2)
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: ahead,
                  color: legColour,
                  width: 6,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
            },
          ),
        ),
        if (!_following)
          Positioned(
            right: 14,
            bottom: 14,
            child: _RecentrePill(onTap: () {
              setState(() => _following = true);
              final here = _motion.position;
              if (here != null) _followCamera(here);
            }),
          ),
        if (_routeError != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _RouteErrorBanner(message: _routeError!),
          ),
      ],
    );
  }
}

class _RecentrePill extends StatelessWidget {
  const _RecentrePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x2916202E),
                  blurRadius: 14,
                  offset: Offset(0, 4)),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location, size: 17, color: Brand.blue),
              SizedBox(width: 7),
              Text('Re-centre',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Brand.ink)),
            ],
          ),
        ),
      );
}

class _RouteErrorBanner extends StatelessWidget {
  const _RouteErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x2916202E), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: Brand.sub),
            const SizedBox(width: 9),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Brand.sub)),
            ),
          ],
        ),
      );
}
