// The earnings screen's money.
//
// It used to offer "Cash out", whose sheet said "Transferred £X to your linked
// bank account" without calling anything, and its weekly figures left tips out
// of the total while subtracting them from trip earnings. These tests keep the
// false confirmation gone and the arithmetic honest.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/account/models/week_earnings.dart';
import 'package:mapcars_driver/src/features/account/presentation/earnings_screen.dart';
import 'package:mapcars_driver/src/features/account/providers/driver_trips_provider.dart';
import 'package:mapcars_driver/src/features/account/services/payout_service.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';

Trip _trip({
  required String completedAtUtc,
  double earnings = 10,
  double tip = 0,
  String status = 'Completed',
}) =>
    Trip.fromJson({
      'id': completedAtUtc,
      'status': status,
      'pickupAddress': 'A',
      'dropoffAddress': 'B',
      'pickupLat': 51.5,
      'pickupLng': -0.1,
      'dropoffLat': 51.6,
      'dropoffLng': -0.2,
      'createdAtUtc': completedAtUtc,
      'completedAtUtc': completedAtUtc,
      'driverEarnings': earnings,
      'tipAmount': tip,
    });

class _Payouts extends PayoutService {
  _Payouts() : super(Dio());

  @override
  Future<PayoutAccount> getAccountStatus() async => const PayoutAccount(
      status: 'enabled', payoutsEnabled: true, chargesEnabled: true);
}

void main() {
  // Wednesday 16 Sep 2026, 12:00 BST.
  final now = DateTime.utc(2026, 9, 16, 11);

  group('WeekEarnings', () {
    test('tips are added to the total, not subtracted from trips', () {
      final w = WeekEarnings.from([
        _trip(completedAtUtc: '2026-09-15T10:00:00Z', earnings: 10, tip: 2),
        _trip(completedAtUtc: '2026-09-16T08:00:00Z', earnings: 8.5),
      ], now: now);
      expect(w.tripPence, 1850);
      expect(w.tipsPence, 200);
      expect(w.totalPence, 2050);
      expect(w.tripCount, 2);
    });

    test('the week starts Monday 00:00 London, not seven days ago', () {
      final w = WeekEarnings.from([
        // Sun 13 Sep 23:30 BST — last week.
        _trip(completedAtUtc: '2026-09-13T22:30:00Z'),
        // Mon 14 Sep 00:30 BST (still Sunday in UTC) — this week, Monday.
        _trip(completedAtUtc: '2026-09-13T23:30:00Z', earnings: 5),
      ], now: now);
      expect(w.tripCount, 1);
      expect(w.dayTotalsPence[0], 500, reason: 'lands on Monday, in UK time');
      expect(w.todayIndex, 2); // Wednesday
    });

    test('only completed trips count', () {
      final w = WeekEarnings.from([
        _trip(completedAtUtc: '2026-09-15T10:00:00Z', status: 'CancelledByCustomer'),
      ], now: now);
      expect(w.tripCount, 0);
      expect(w.totalPence, 0);
    });
  });

  testWidgets('no cash-out, no fake transfer — statements instead',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        payoutServiceProvider.overrideWithValue(_Payouts()),
        driverTripsProvider.overrideWith((ref) async => [
              _trip(
                  completedAtUtc:
                      DateTime.now().toUtc().toIso8601String(),
                  earnings: 12,
                  tip: 1),
            ]),
      ],
      child: const MaterialApp(home: EarningsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cash out'), findsNothing);
    expect(find.textContaining('Transferred'), findsNothing);
    expect(find.textContaining('Paid weekly'), findsOneWidget);
    expect(find.text('Weekly statements'), findsOneWidget);
  });
}
