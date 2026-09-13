import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Small shared geometry helpers for the map layers.
///
/// These were previously copy-pasted into every widget that drew a moving car,
/// which is how the rider's own car ended up snapping its heading while the
/// scenery cars around it turned smoothly — same idea, two implementations,
/// only one of them finished.

const earthRadiusMeters = 6371000.0;

double radians(double degrees) => degrees * math.pi / 180.0;

/// Equirectangular approximation. Accurate well past the few hundred metres a
/// car covers between fixes, and far cheaper than haversine — which matters
/// when this runs per frame against a route of several hundred vertices.
double metersBetween(LatLng a, LatLng b) {
  final latRad = radians((a.latitude + b.latitude) / 2);
  final dx = radians(b.longitude - a.longitude) * math.cos(latRad);
  final dy = radians(b.latitude - a.latitude);
  return math.sqrt(dx * dx + dy * dy) * earthRadiusMeters;
}

/// Compass bearing a→b in degrees (0 = north, clockwise).
double bearingBetween(LatLng a, LatLng b) {
  final lat1 = radians(a.latitude);
  final lat2 = radians(b.latitude);
  final dLng = radians(b.longitude - a.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
}

/// Interpolate a compass heading the short way round: 350° → 10° is a 20° turn
/// to the right, not 340° to the left. Without this a car crossing north spins
/// almost all the way around on the spot.
double lerpHeading(double from, double to, double t) {
  final delta = (to - from + 540.0) % 360.0 - 180.0;
  return (from + delta * t + 360.0) % 360.0;
}

/// Straight-line interpolation between two positions.
LatLng lerpLatLng(LatLng a, LatLng b, double t) => LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );

/// The position [meters] away from [from] on compass [bearingDegrees].
/// Used to carry a car forward on its last known heading when its next fix is
/// late, so it doesn't freeze mid-road.
LatLng offsetLatLng(LatLng from, double meters, double bearingDegrees) {
  final bearing = radians(bearingDegrees);
  final dLat = meters * math.cos(bearing) / earthRadiusMeters;
  final dLng = meters *
      math.sin(bearing) /
      (earthRadiusMeters * math.cos(radians(from.latitude)));
  return LatLng(
    from.latitude + dLat * 180.0 / math.pi,
    from.longitude + dLng * 180.0 / math.pi,
  );
}
