import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geo_math.dart';

/// Where a position sits relative to a route.
class RouteFix {
  const RouteFix({
    required this.alongMeters,
    required this.offsetMeters,
    required this.point,
  });

  /// Distance from the start of the route to the projected point.
  final double alongMeters;

  /// Perpendicular distance from the route — how far off the road the raw fix
  /// landed. Large values mean the driver isn't on this route any more.
  final double offsetMeters;

  /// The raw position projected onto the route line.
  final LatLng point;
}

/// A route polyline you can project onto and travel along.
///
/// The map widgets used to answer "how far is left?" by finding the nearest
/// *vertex* and summing from there. Google's polylines are sparse on straights —
/// two vertices can sit 200m apart — so on a long road the nearest vertex could
/// be 100m away while the true perpendicular foot was 3m away. That inflated the
/// ETA and let the trimmed route line jump backwards.
///
/// This projects onto the nearest *segment* instead, and precomputes cumulative
/// distances so travelling along the line is a lookup rather than a re-sum.
class RoutePath {
  RoutePath(List<LatLng> points)
      : points = List.unmodifiable(points),
        _cumulative = _measure(points);

  final List<LatLng> points;

  /// `_cumulative[i]` = metres from the route start to `points[i]`.
  final List<double> _cumulative;

  static List<double> _measure(List<LatLng> points) {
    final out = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      out[i] = out[i - 1] + metersBetween(points[i - 1], points[i]);
    }
    return out;
  }

  bool get isUsable => points.length >= 2;

  double get lengthMeters => _cumulative.isEmpty ? 0 : _cumulative.last;

  /// Projects [at] onto the nearest point of the route.
  ///
  /// [nearAlongMeters] restricts the search to a window around a known previous
  /// position. That is both faster and *more correct*: a route that doubles back
  /// on itself (a loop, or an out-and-back) has two nearby candidate segments,
  /// and without a hint the car can teleport to the wrong leg.
  RouteFix project(
    LatLng at, {
    double? nearAlongMeters,
    double windowMeters = 400,
  }) {
    if (points.isEmpty) {
      return RouteFix(alongMeters: 0, offsetMeters: 0, point: at);
    }
    if (points.length == 1) {
      return RouteFix(
        alongMeters: 0,
        offsetMeters: metersBetween(at, points.first),
        point: points.first,
      );
    }

    var bestOffset = double.infinity;
    var bestAlong = 0.0;
    var bestPoint = points.first;

    for (var i = 0; i < points.length - 1; i++) {
      if (nearAlongMeters != null) {
        // Skip segments wholly outside the window around the last known spot.
        if (_cumulative[i + 1] < nearAlongMeters - windowMeters) continue;
        if (_cumulative[i] > nearAlongMeters + windowMeters) break;
      }

      final a = points[i];
      final b = points[i + 1];
      final segmentMeters = _cumulative[i + 1] - _cumulative[i];
      // Duplicate consecutive vertices are common in encoded polylines.
      if (segmentMeters <= 0) continue;

      final t = _projectOntoSegment(at, a, b);
      final along = _cumulative[i] + segmentMeters * t;
      // Segments can be hundreds of metres long, so overlapping the window is
      // not enough — the projected point itself has to fall inside it, or a
      // long outbound segment wins back a car that is already on the return leg.
      if (nearAlongMeters != null &&
          (along - nearAlongMeters).abs() > windowMeters) {
        continue;
      }

      final foot = lerpLatLng(a, b, t);
      final offset = metersBetween(at, foot);
      if (offset < bestOffset) {
        bestOffset = offset;
        bestAlong = along;
        bestPoint = foot;
      }
    }

    // A hint window that matched nothing (the car is past the end, say) — retry
    // unhinted rather than reporting a bogus projection at the route start.
    if (bestOffset == double.infinity) {
      return nearAlongMeters == null
          ? RouteFix(alongMeters: 0, offsetMeters: 0, point: at)
          : project(at);
    }

    return RouteFix(
      alongMeters: bestAlong,
      offsetMeters: bestOffset,
      point: bestPoint,
    );
  }

  /// How far along segment a→b the closest point to [p] lies, clamped to 0..1.
  ///
  /// Works in a local metre frame anchored at [a], so longitude is scaled by
  /// latitude — without that, the projection skews badly away from the equator
  /// (at London's 51.5°N a degree of longitude is only ~62% of a degree of
  /// latitude, so an unscaled dot product picks the wrong point on the segment).
  static double _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    final scale = math.cos(radians(a.latitude));
    final abx = (b.longitude - a.longitude) * scale;
    final aby = b.latitude - a.latitude;
    final apx = (p.longitude - a.longitude) * scale;
    final apy = p.latitude - a.latitude;

    final lengthSquared = abx * abx + aby * aby;
    if (lengthSquared <= 0) return 0;
    return ((apx * abx + apy * aby) / lengthSquared).clamp(0.0, 1.0);
  }

  /// The position [alongMeters] into the route.
  LatLng pointAt(double alongMeters) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (points.length == 1) return points.first;

    final along = alongMeters.clamp(0.0, lengthMeters);
    final i = _segmentAt(along);
    final segmentMeters = _cumulative[i + 1] - _cumulative[i];
    if (segmentMeters <= 0) return points[i];
    return lerpLatLng(
      points[i],
      points[i + 1],
      (along - _cumulative[i]) / segmentMeters,
    );
  }

  /// The direction the road runs at [alongMeters] — a far better heading than
  /// GPS, which is noise below walking pace.
  double bearingAt(double alongMeters) {
    if (points.length < 2) return 0;
    final i = _segmentAt(alongMeters.clamp(0.0, lengthMeters));
    return bearingBetween(points[i], points[i + 1]);
  }

  /// Metres still to travel from [alongMeters] to the end of the route.
  double remainingFrom(double alongMeters) =>
      (lengthMeters - alongMeters).clamp(0.0, lengthMeters);

  /// The route from [alongMeters] onward, starting at the exact point rather
  /// than at the next vertex — so the drawn line begins under the car instead
  /// of snapping to whichever vertex happens to be closest.
  List<LatLng> pointsFrom(double alongMeters) {
    if (points.length < 2) return points;
    final along = alongMeters.clamp(0.0, lengthMeters);
    final i = _segmentAt(along);
    return [pointAt(along), ...points.sublist(i + 1)];
  }

  /// Index of the segment containing [along]; binary search over the
  /// precomputed distances rather than a scan, since this runs per frame.
  int _segmentAt(double along) {
    var low = 0;
    var high = points.length - 2;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_cumulative[mid] <= along) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}
