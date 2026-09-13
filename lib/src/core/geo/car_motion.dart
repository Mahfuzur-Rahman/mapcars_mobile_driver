import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geo_math.dart';
import 'route_path.dart';

/// Smooth on-screen motion for one car fed by sparse GPS fixes.
///
/// A car reports every ~5s but the map draws at 12fps, so almost every frame is
/// invented. Everything here is about inventing them convincingly:
///
/// * **Glide, don't teleport.** Interpolate from where the car is *drawn* to the
///   newest fix — never from the previous fix, or a late update makes the car
///   jump backwards before setting off again.
/// * **Follow the road, not the GPS.** With a [route], the glide interpolates a
///   single scalar — distance travelled along the polyline — and the position is
///   read off the line. Lateral GPS noise is projected away for free, and the
///   car physically cannot cut a corner or drive through a building.
/// * **Turn the short way round.** 350 to 10 degrees is a 20 degree right turn.
/// * **Match the glide to the real cadence.** The glide window tracks the
///   observed gap between fixes, so a car whose updates arrive every 8s glides
///   for 8s instead of finishing early and freezing for 3.
/// * **Coast briefly when a fix is late**, but only when already moving, so a
///   car stopped at a red light never creeps forward through the junction.
///
/// [position] and [heading] are computed from the clock on read, so a caller
/// repaints on a timer and asks — there is no tick to drive.
class CarMotion {
  CarMotion({
    DateTime Function()? clock,
    this.minGlide = const Duration(seconds: 2),
    this.maxGlide = const Duration(seconds: 8),
    this.maxCoast = const Duration(milliseconds: 1500),
    this.snapMeters = 400,
    this.headingMeters = 6,
    this.maxOffsetMeters = 30,
    this.coastMinSpeed = 3.0,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Bounds on the adaptive glide window.
  final Duration minGlide;
  final Duration maxGlide;

  /// How long the car may carry on past its last fix before it stops and waits.
  final Duration maxCoast;

  /// A position change bigger than this isn't driving — it's a reconnect or a
  /// GPS glitch. Snap, rather than sliding the car across half of London.
  final double snapMeters;

  /// Below this, movement is GPS noise: keep the last heading rather than
  /// spinning a stationary car on the spot.
  final double headingMeters;

  /// How far off the route a fix may land and still count as "on it". Beyond
  /// this the driver has left the route — a wrong turn, or a route gone stale
  /// after the destination changed — and snapping would drag the car sideways
  /// onto a road it isn't on, so we fall back to plain interpolation until the
  /// route is refetched.
  final double maxOffsetMeters;

  /// Coasting is only for a car that was already moving. Without this floor, a
  /// car stopped at a light — which reports no fixes at all under a distance
  /// filter — would creep forward on invented movement.
  final double coastMinSpeed;

  /// Glide window used before any cadence has been observed. Just under the
  /// apps' 5s push interval, so the first slide settles rather than being cut.
  static const _defaultGlide = Duration(milliseconds: 4500);

  RoutePath? _route;

  LatLng? _fromPoint;
  LatLng? _toPoint;
  double _fromAlong = 0;
  double _toAlong = 0;
  bool _onRoute = false;

  double _fromHeading = 0;
  double _toHeading = 0;

  DateTime? _startedAt;
  Duration _duration = Duration.zero;

  DateTime? _lastFixAt;
  Duration? _cadence;

  /// Ground speed in m/s across the last pair of fixes, used for coasting.
  double _speed = 0;

  RoutePath? get route => _route;

  /// Swap in a freshly fetched route. Both apps refetch from the driver's
  /// current position, so distances along the old line mean nothing on the new
  /// one — rebase onto where the car is drawn right now and let the next fix
  /// resume the glide from there.
  set route(RoutePath? value) {
    if (identical(_route, value)) return;
    // Read where the car is drawn *before* swapping the line out. Reading after
    // would resolve the old along-distance against the new route and teleport
    // the car by however much the two disagree.
    final shown = position;
    _route = value;
    if (value == null || !value.isUsable || shown == null) {
      _onRoute = false;
      return;
    }
    final fix = value.project(shown);
    _onRoute = fix.offsetMeters <= maxOffsetMeters;
    _fromAlong = _toAlong = fix.alongMeters;
    _fromPoint = _toPoint = shown;
    _duration = Duration.zero;
  }

  /// True once the car has somewhere to be drawn.
  bool get hasPosition => _toPoint != null;

  /// How far along the route the car is drawn, or null when it isn't following
  /// one. Callers use this for the remaining distance and the trimmed polyline,
  /// so both agree with what the rider can actually see.
  double? get alongMeters {
    if (!_onRoute || _route == null) return null;
    return _fromAlong + (_toAlong - _fromAlong) * _progress + _coastMeters();
  }

  /// Where to draw the car right now.
  LatLng? get position {
    final to = _toPoint;
    final from = _fromPoint;
    if (to == null || from == null) return null;

    final route = _route;
    if (_onRoute && route != null && route.isUsable) {
      return route.pointAt(alongMeters!);
    }

    final at = lerpLatLng(from, to, _progress);
    final coast = _coastMeters();
    return coast <= 0 ? at : offsetLatLng(at, coast, _toHeading);
  }

  /// Which way to point the car right now.
  double get heading => lerpHeading(_fromHeading, _toHeading, _progress);

  /// Whether anything is still changing — callers use this to stop repainting a
  /// screen full of parked cars. Note this goes false once the coast has run
  /// out, not merely once the coast distance is non-zero: that distance stays
  /// non-zero for as long as the car sits at its capped-out position.
  bool get isMoving => _progress < 1 || _isCoasting;

  bool get _isCoasting {
    final overrun = _overrun();
    return overrun != null && overrun > Duration.zero && overrun < maxCoast;
  }

  /// How long past the end of the glide we are, or null when not gliding.
  Duration? _overrun() {
    final startedAt = _startedAt;
    if (startedAt == null || _duration <= Duration.zero) return null;
    return _clock().difference(startedAt) - _duration;
  }

  double get _progress {
    final startedAt = _startedAt;
    if (startedAt == null || _duration <= Duration.zero) return 1;
    final elapsed = _clock().difference(startedAt).inMilliseconds;
    return (elapsed / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Extra metres travelled past the last fix while waiting for the next one.
  double _coastMeters() {
    if (_speed < coastMinSpeed) return 0;
    final overrun = _overrun();
    if (overrun == null || overrun <= Duration.zero) return 0;
    final capped = overrun > maxCoast ? maxCoast : overrun;
    return _speed * capped.inMilliseconds / 1000.0;
  }

  /// Fold a new fix into the animation. [reportedHeading] wins when the device
  /// sent one and the car is not following a route; on a route the road's own
  /// direction is used instead, because GPS heading is noise below walking pace.
  void onFix(LatLng at, {double? reportedHeading}) {
    final now = _clock();
    final previousFixAt = _lastFixAt;
    _lastFixAt = now;

    // Track the real cadence so the glide lasts until the next fix is actually
    // due, instead of finishing early and leaving the car stalled.
    if (previousFixAt != null) {
      final gap = now.difference(previousFixAt);
      if (gap > Duration.zero && gap <= maxGlide * 2) {
        _cadence = _cadence == null
            ? gap
            : Duration(
                milliseconds:
                    (_cadence!.inMilliseconds * 0.6 + gap.inMilliseconds * 0.4)
                        .round());
      }
    }

    final shown = position;
    if (shown == null) {
      _adoptImmediately(at, reportedHeading);
      return;
    }

    final moved = metersBetween(shown, at);
    if (moved > snapMeters) {
      // Not driving — a reconnect or a GPS glitch. Take it as read.
      _adoptImmediately(at, reportedHeading);
      return;
    }

    _speed = previousFixAt == null
        ? 0
        : moved / (now.difference(previousFixAt).inMilliseconds / 1000.0);

    final route = _route;
    final fix = (route != null && route.isUsable)
        ? route.project(at, nearAlongMeters: _onRoute ? _toAlong : null)
        : null;

    _fromPoint = shown;
    _toPoint = at;
    _fromHeading = heading;
    _startedAt = now;
    _duration = _glideWindow();

    if (fix != null && fix.offsetMeters <= maxOffsetMeters) {
      _fromAlong = route!.project(shown, nearAlongMeters: _toAlong).alongMeters;
      _toAlong = fix.alongMeters;
      _onRoute = true;
      // The road's own direction, interpolated across the glide rather than
      // applied instantly — so a junction turns the car over a second or two
      // instead of flipping it within a single frame.
      _toHeading = route.bearingAt(fix.alongMeters);
    } else {
      _onRoute = false;
      _toHeading = reportedHeading ??
          (moved >= headingMeters ? bearingBetween(shown, at) : _toHeading);
    }
  }

  /// Take a position as gospel — first fix, or a jump too big to animate.
  void _adoptImmediately(LatLng at, double? reportedHeading) {
    _fromPoint = _toPoint = at;
    _fromHeading = _toHeading = reportedHeading ?? _toHeading;
    _startedAt = _clock();
    _duration = Duration.zero;
    _speed = 0;

    final route = _route;
    if (route != null && route.isUsable) {
      final fix = route.project(at);
      _onRoute = fix.offsetMeters <= maxOffsetMeters;
      _fromAlong = _toAlong = fix.alongMeters;
      if (_onRoute && reportedHeading == null) {
        _fromHeading = _toHeading = route.bearingAt(fix.alongMeters);
      }
    } else {
      _onRoute = false;
    }
  }

  /// Glide for as long as the next fix is expected to take, within bounds.
  Duration _glideWindow() {
    final cadence = _cadence;
    if (cadence == null) return _defaultGlide;
    // Settle a touch before the next fix rather than exactly on it, so a fix
    // that arrives slightly early doesn't cut the slide off mid-stride.
    final target =
        Duration(milliseconds: (cadence.inMilliseconds * 0.92).round());
    if (target < minGlide) return minGlide;
    if (target > maxGlide) return maxGlide;
    return target;
  }
}
