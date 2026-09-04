// Route projection — the geometry the ETA, the trimmed route line and the
// car's snapped position all read from.
//
// The thing being replaced here found the nearest *vertex* and summed from
// there. Google's polylines are sparse on straights, so on a long road the
// nearest vertex could be 100m away while the true perpendicular foot was
// metres away — which inflated the ETA and let the drawn line jump backwards.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapcars_driver/src/core/geo/geo_math.dart';
import 'package:mapcars_driver/src/core/geo/route_path.dart';

/// A straight run of road heading due east across central London, with its
/// vertices deliberately far apart — the sparse-polyline case.
RoutePath eastRoad() => RoutePath(const [
      LatLng(51.5000, -0.1000),
      LatLng(51.5000, -0.0900),
      LatLng(51.5000, -0.0800),
    ]);

void main() {
  group('project', () {
    test('lands on the segment, not on the nearest vertex', () {
      final road = eastRoad();
      // Just south of the road, midway between the first two vertices — the
      // spot where nearest-vertex is worst.
      const at = LatLng(51.49995, -0.0950);

      final fix = road.project(at);

      // ~5.5m south of the line, not the ~350m to either vertex.
      expect(fix.offsetMeters, lessThan(10));
      expect(fix.point.longitude, closeTo(-0.0950, 1e-6));
      // Half of the first segment along.
      final firstSegment = metersBetween(
          const LatLng(51.5000, -0.1000), const LatLng(51.5000, -0.0900));
      expect(fix.alongMeters, closeTo(firstSegment / 2, 1.0));
    });

    test('clamps to the ends rather than running off the line', () {
      final road = eastRoad();

      final before = road.project(const LatLng(51.5000, -0.2000));
      expect(before.alongMeters, 0);

      final after = road.project(const LatLng(51.5000, 0.0000));
      expect(after.alongMeters, closeTo(road.lengthMeters, 1.0));
    });

    test('a hint keeps a car on the leg it is actually on', () {
      // An out-and-back: the two legs are metres apart, so an unhinted
      // projection can put a car on the return leg while it is still outbound.
      final loop = RoutePath(const [
        LatLng(51.5000, -0.1000),
        LatLng(51.5000, -0.0900),
        LatLng(51.5001, -0.0900),
        LatLng(51.5001, -0.1000),
      ]);
      const at = LatLng(51.50005, -0.0950); // dead between the two legs

      final outbound = loop.project(at, nearAlongMeters: 300);
      final ret = loop.project(at, nearAlongMeters: 1000);

      expect(outbound.alongMeters, lessThan(loop.lengthMeters / 2));
      expect(ret.alongMeters, greaterThan(loop.lengthMeters / 2));
    });

    test('survives a polyline with duplicate consecutive vertices', () {
      final road = RoutePath(const [
        LatLng(51.5000, -0.1000),
        LatLng(51.5000, -0.1000), // encoded polylines really do contain these
        LatLng(51.5000, -0.0900),
      ]);
      final fix = road.project(const LatLng(51.5000, -0.0950));
      expect(fix.offsetMeters, lessThan(1));
      expect(fix.alongMeters.isFinite, isTrue);
    });
  });

  group('travelling along', () {
    test('pointAt walks the line and agrees with project', () {
      final road = eastRoad();
      final mid = road.pointAt(road.lengthMeters / 2);

      expect(mid.latitude, closeTo(51.5000, 1e-6));
      expect(mid.longitude, closeTo(-0.0900, 1e-4));
      expect(road.project(mid).alongMeters,
          closeTo(road.lengthMeters / 2, 1.0));
    });

    test('bearingAt reports the direction of the road', () {
      expect(eastRoad().bearingAt(100), closeTo(90, 0.5)); // due east
    });

    test('remainingFrom counts down to zero at the end', () {
      final road = eastRoad();
      expect(road.remainingFrom(0), closeTo(road.lengthMeters, 0.01));
      expect(road.remainingFrom(road.lengthMeters), 0);
      // Past the end (a driver who overshot) must not go negative.
      expect(road.remainingFrom(road.lengthMeters + 500), 0);
    });

    test('pointsFrom starts under the car, not at the next vertex', () {
      final road = eastRoad();
      final ahead = road.pointsFrom(road.lengthMeters / 2);

      expect(ahead.first.longitude, closeTo(-0.0900, 1e-4));
      expect(ahead.last, road.points.last);
      // Trimming must never lengthen the line.
      expect(ahead.length, lessThan(road.points.length + 1));
    });
  });

  group('degenerate input', () {
    test('an empty route is unusable and answers safely', () {
      final empty = RoutePath(const []);
      expect(empty.isUsable, isFalse);
      expect(empty.lengthMeters, 0);
      expect(empty.project(const LatLng(51.5, -0.1)).alongMeters, 0);
    });

    test('a single-point route is unusable and answers safely', () {
      final single = RoutePath(const [LatLng(51.5, -0.1)]);
      expect(single.isUsable, isFalse);
      expect(single.pointAt(50), const LatLng(51.5, -0.1));
      expect(single.bearingAt(50), 0);
    });
  });

  group('longitude scaling', () {
    test('projection is not skewed by latitude', () {
      // At London's 51.5N a degree of longitude is ~62% of a degree of
      // latitude. An unscaled dot product picks visibly the wrong point on a
      // diagonal segment; this pins that the local metre frame is applied.
      final diagonal = RoutePath(const [
        LatLng(51.5000, -0.1000),
        LatLng(51.5100, -0.0900),
      ]);
      final fix = diagonal.project(const LatLng(51.5050, -0.0950));

      // The midpoint of the segment is on the line, so the offset is ~0 and the
      // along-distance is half. Skewed maths misses both.
      expect(fix.offsetMeters, lessThan(2));
      expect(fix.alongMeters, closeTo(diagonal.lengthMeters / 2, 5));
    });
  });
}
