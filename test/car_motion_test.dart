// The car animator.
//
// Cars report every ~5s and the map draws at 12fps, so nearly every frame on
// screen is invented. These pin the invented frames: that the car glides rather
// than teleports, turns the short way round, follows the road instead of cutting
// the corner between two GPS fixes, keeps moving when a fix is late, and — the
// one that is easy to get wrong in the other direction — does *not* creep
// forward when it is parked.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapcars_driver/src/core/geo/car_motion.dart';
import 'package:mapcars_driver/src/core/geo/geo_math.dart';
import 'package:mapcars_driver/src/core/geo/route_path.dart';

/// Hand-wound clock, so a 5s glide costs the suite nothing.
class FakeClock {
  DateTime _now = DateTime.utc(2026, 1, 1, 12);
  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

/// A right-angle turn: 500m due east, then 500m due north. The corner is the
/// interesting part — a straight lerp between a fix before it and a fix after
/// it cuts diagonally across the inside of the bend.
RoutePath corner() => RoutePath(const [
      LatLng(51.5000, -0.1000),
      LatLng(51.5000, -0.0928), // ~500m east
      LatLng(51.5045, -0.0928), // ~500m north
    ]);

void main() {
  group('gliding', () {
    test('the first fix is adopted immediately', () {
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5, -0.1));

      expect(car.position, const LatLng(51.5, -0.1));
      expect(car.isMoving, isFalse);
    });

    test('a later fix is glided to, not jumped to', () {
      final clock = FakeClock();
      // Coasting off, so this isolates the glide itself — carrying on past the
      // target when a fix is late is real behaviour, tested separately below.
      final car = CarMotion(clock: clock.call, maxCoast: Duration.zero);
      car.onFix(const LatLng(51.5000, -0.1000));
      clock.advance(const Duration(seconds: 5));
      car.onFix(const LatLng(51.5000, -0.0990));

      // Immediately after the fix the car is still at the old spot.
      expect(car.position!.longitude, closeTo(-0.1000, 1e-6));
      expect(car.isMoving, isTrue);

      clock.advance(const Duration(milliseconds: 2250));
      expect(car.position!.longitude, closeTo(-0.0995, 1e-4));

      clock.advance(const Duration(seconds: 10));
      expect(car.position!.longitude, closeTo(-0.0990, 1e-6));
    });

    test('a glide interrupted mid-slide continues from where it is drawn',
        () {
      // The bug this prevents: resuming from the previous *fix* instead of the
      // drawn position makes the car visibly jump backwards on every update.
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5000, -0.1000));
      clock.advance(const Duration(seconds: 5));
      car.onFix(const LatLng(51.5000, -0.0990));

      clock.advance(const Duration(seconds: 2));
      final midway = car.position!.longitude;
      car.onFix(const LatLng(51.5000, -0.0980));

      expect(car.position!.longitude, closeTo(midway, 1e-9));
    });

    test('a jump too big to be driving snaps instead of sliding', () {
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5000, -0.1000));
      clock.advance(const Duration(seconds: 5));
      car.onFix(const LatLng(51.6000, -0.1000)); // ~11km — a reconnect

      expect(car.position!.latitude, closeTo(51.6000, 1e-6));
      expect(car.isMoving, isFalse);
    });
  });

  group('heading', () {
    test('turns the short way round across north', () {
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5, -0.1), reportedHeading: 350);
      clock.advance(const Duration(seconds: 5));
      car.onFix(const LatLng(51.5, -0.1 + 0.0001), reportedHeading: 10);

      clock.advance(const Duration(milliseconds: 2250));
      // Halfway through a 20 degree right turn: 0, not 180.
      final heading = car.heading;
      expect(heading > 355 || heading < 5, isTrue,
          reason: 'went the long way round: $heading');
    });

    test('is interpolated across the glide, not snapped on arrival', () {
      // The rider's own car used to snap its rotation the instant a fix landed
      // and then slide in that direction — it pivoted on the spot.
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5, -0.1), reportedHeading: 0);
      clock.advance(const Duration(seconds: 5));
      car.onFix(const LatLng(51.5, -0.1 + 0.0001), reportedHeading: 90);

      expect(car.heading, closeTo(0, 0.01)); // not yet turned
      clock.advance(const Duration(milliseconds: 2250));
      expect(car.heading, closeTo(45, 2)); // mid-turn
    });

    test('a stationary car keeps its heading instead of spinning', () {
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5, -0.1), reportedHeading: 270);
      clock.advance(const Duration(seconds: 5));
      // A metre of GPS noise, no reported heading.
      car.onFix(const LatLng(51.500001, -0.100001));

      clock.advance(const Duration(seconds: 10));
      expect(car.heading, closeTo(270, 0.01));
    });
  });

  group('following the road', () {
    test('takes the corner instead of cutting across it', () {
      final clock = FakeClock();
      final road = corner();
      final car = CarMotion(clock: clock.call)..route = road;

      car.onFix(road.pointAt(400)); // approaching the corner
      clock.advance(const Duration(seconds: 5));
      car.onFix(road.pointAt(600)); // just past it, onto the second leg

      clock.advance(const Duration(milliseconds: 2250));
      final at = car.position!;

      // Halfway through the glide the car should be at the corner itself —
      // a straight lerp would put it well inside the bend.
      final offRoute = road.project(at).offsetMeters;
      expect(offRoute, lessThan(5),
          reason: 'car left the road by ${offRoute}m');

      final cutting = metersBetween(at, road.points[1]);
      expect(cutting, lessThan(30), reason: 'cut the corner by ${cutting}m');
    });

    test('projects lateral GPS noise away', () {
      final clock = FakeClock();
      final road = corner();
      final car = CarMotion(clock: clock.call)..route = road;

      car.onFix(road.pointAt(100));
      clock.advance(const Duration(seconds: 5));
      // 15m north of the road — plausible urban GPS error.
      final noisy = offsetLatLng(road.pointAt(200), 15, 0);
      car.onFix(noisy);

      clock.advance(const Duration(seconds: 10));
      expect(road.project(car.position!).offsetMeters, lessThan(1));
    });

    test('reports how far along the route it is drawn', () {
      final clock = FakeClock();
      final road = corner();
      final car = CarMotion(clock: clock.call)..route = road;

      car.onFix(road.pointAt(100));
      expect(car.alongMeters, closeTo(100, 2));

      clock.advance(const Duration(seconds: 5));
      car.onFix(road.pointAt(300));
      clock.advance(const Duration(milliseconds: 2250));
      expect(car.alongMeters, closeTo(200, 20));
    });

    test('stops snapping once the driver has left the route', () {
      final clock = FakeClock();
      final road = corner();
      final car = CarMotion(clock: clock.call, maxCoast: Duration.zero)
        ..route = road;

      car.onFix(road.pointAt(100));
      clock.advance(const Duration(seconds: 5));
      // 120m off the line — a wrong turn, not GPS noise. Dragging the car back
      // onto the route here would draw it on a road it is not on.
      final strayed = offsetLatLng(road.pointAt(200), 120, 0);
      car.onFix(strayed);

      clock.advance(const Duration(seconds: 10));
      expect(car.alongMeters, isNull);
      expect(metersBetween(car.position!, strayed), lessThan(1));
    });

    test('a refetched route rebases without teleporting the car', () {
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call)..route = corner();
      car.onFix(corner().pointAt(300));
      final before = car.position!;

      // Both apps refetch the route starting from the driver's position, so
      // along-distances on the old line mean nothing on the new one.
      car.route = RoutePath([before, const LatLng(51.5045, -0.0928)]);

      expect(metersBetween(car.position!, before), lessThan(1));
      expect(car.alongMeters, closeTo(0, 1));
    });
  });

  group('late fixes', () {
    test('the glide window adapts to the observed cadence', () {
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);

      // Three fixes 8s apart teaches it an 8s cadence.
      car.onFix(const LatLng(51.5000, -0.1000));
      clock.advance(const Duration(seconds: 8));
      car.onFix(const LatLng(51.5000, -0.0995));
      clock.advance(const Duration(seconds: 8));
      car.onFix(const LatLng(51.5000, -0.0990));

      // At 5s a fixed 4.5s glide would already have finished and frozen.
      clock.advance(const Duration(seconds: 5));
      expect(car.isMoving, isTrue);
    });

    test('a moving car coasts through a late fix', () {
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5000, -0.1000));
      clock.advance(const Duration(seconds: 5));
      car.onFix(const LatLng(51.5000, -0.0990)); // ~70m in 5s = 14 m/s

      clock.advance(const Duration(milliseconds: 4500));
      final atGlideEnd = car.position!;
      clock.advance(const Duration(milliseconds: 1000));

      expect(metersBetween(car.position!, atGlideEnd), greaterThan(5));
    });

    test('coasting is capped, so a dropped car does not drive off', () {
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5000, -0.1000));
      clock.advance(const Duration(seconds: 5));
      car.onFix(const LatLng(51.5000, -0.0990));

      clock.advance(const Duration(minutes: 5));
      final far = car.position!;
      clock.advance(const Duration(minutes: 5));

      expect(metersBetween(car.position!, far), lessThan(1));
      expect(car.isMoving, isFalse);
    });

    test('a parked car never creeps forward', () {
      // The risk of coasting: a car stopped at a light reports nothing under a
      // distance filter, and inventing movement would push it into the junction.
      final clock = FakeClock();
      final car = CarMotion(clock: clock.call);
      car.onFix(const LatLng(51.5000, -0.1000));
      clock.advance(const Duration(seconds: 5));
      car.onFix(const LatLng(51.5000, -0.100001)); // crawled ~7cm

      clock.advance(const Duration(seconds: 30));
      expect(metersBetween(car.position!, const LatLng(51.5000, -0.100001)),
          lessThan(1));
      expect(car.isMoving, isFalse);
    });
  });
}
