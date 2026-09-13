// Unit tests for the request-expiry client logic on the driver side: parsing
// the request's deadline, and the countdown's clock-skew correction.
//
// Whether an accept succeeds is the API's decision, made on its own clock. What
// is tested here is the part that can be silently wrong: the number of seconds
// a driver is shown before deciding whether to take a job.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/utils/server_clock.dart';
import 'package:mapcars_driver/src/core/widgets/countdown.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';

Map<String, dynamic> _tripJson({String status = 'Requested', String? expires}) => {
      'id': 'trip-1',
      'status': status,
      'pickupAddress': 'Kings Cross',
      'pickupLat': 51.5308,
      'pickupLng': -0.1238,
      'dropoffAddress': 'Soho',
      'dropoffLat': 51.5136,
      'dropoffLng': -0.1365,
      'createdAtUtc': '2026-09-07T10:00:00Z',
      if (expires != null) 'expiresAtUtc': expires,
    };

void main() {
  group('TripStatus.fromJson', () {
    test('parses Expired', () {
      expect(TripStatus.fromJson('Expired'), TripStatus.expired);
    });

    test('still parses the statuses it always did', () {
      expect(TripStatus.fromJson('Requested'), TripStatus.requested);
      expect(TripStatus.fromJson('CancelledByDriver'), TripStatus.cancelledByDriver);
      expect(TripStatus.fromJson('Nonsense'), TripStatus.unknown);
      expect(TripStatus.fromJson(null), TripStatus.unknown);
    });
  });

  group('Trip.fromJson', () {
    test('reads the request deadline', () {
      final trip = Trip.fromJson(_tripJson(expires: '2026-09-07T10:03:00Z'));
      expect(trip.expiresAtUtc, DateTime.utc(2026, 9, 7, 10, 3));
    });

    test('leaves the deadline null for a trip that has none', () {
      // Trips booked before the column existed, and everything in the history
      // list. The card renders no chip at all rather than a stuck 0:00.
      expect(Trip.fromJson(_tripJson()).expiresAtUtc, isNull);
    });
  });

  group('ServerClock', () {
    tearDown(() => ServerClock.offsetForTest = Duration.zero);

    test('counts down on the server clock, not the device clock', () {
      // A handset running two minutes fast. On the server the request still has
      // a minute left, and that is what the driver has to see — the device-clock
      // answer would grey the card out on a job that is still there to take.
      ServerClock.offsetForTest = const Duration(minutes: -2);
      final deadline = DateTime.now().toUtc().subtract(const Duration(seconds: 60));

      expect(ServerClock.remainingUntil(deadline).inSeconds, closeTo(60, 1));
    });

    test('clamps a passed deadline to zero rather than going negative', () {
      final past = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      expect(ServerClock.remainingUntil(past), Duration.zero);
    });

    test('treats a missing deadline as elapsed', () {
      expect(ServerClock.remainingUntil(null), Duration.zero);
    });
  });

  group('formatCountdown', () {
    test('renders m:ss', () {
      expect(formatCountdown(const Duration(minutes: 2, seconds: 5)), '2:05');
      expect(formatCountdown(const Duration(seconds: 59)), '0:59');
      expect(formatCountdown(Duration.zero), '0:00');
    });

    test('floors part-seconds instead of rounding up', () {
      expect(formatCountdown(const Duration(milliseconds: 1900)), '0:01');
    });
  });
}
