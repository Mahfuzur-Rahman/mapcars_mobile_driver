// What a driver is told about money at drop-off.
//
// The one thing that must never happen is a driver being prompted to collect
// cash on a card trip — the customer is charged by the platform, and asking
// them to pay again in person is a complaint (or a double charge) waiting to
// happen. Card declines are hidden from drivers by the API, so no card-failure
// wording may appear either, whatever the payment status says.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/drive/presentation/widgets/drop_off_payment.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';

Trip _trip(String? method, {String status = 'Pending'}) => Trip.fromJson({
      'id': 't1',
      'status': 'InProgress',
      'pickupAddress': 'A',
      'dropoffAddress': 'B',
      'pickupLat': 51.5,
      'pickupLng': -0.1,
      'dropoffLat': 51.6,
      'dropoffLng': -0.2,
      'createdAtUtc': '2026-09-01T12:00:00Z',
      'fareAmount': 12.5,
      'tipAmount': 2,
      if (method != null) 'paymentMethod': method,
      'paymentStatus': status,
    });

Future<void> _pump(WidgetTester tester, Trip trip) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: DropOffPaymentBanner(trip: trip))),
    );

void main() {
  group('payment method parsing', () {
    test('is case-insensitive', () {
      for (final m in ['Card', 'card', 'CARD', ' Card ']) {
        expect(_trip(m).isCard, isTrue, reason: m);
        expect(_trip(m).isCash, isFalse, reason: m);
      }
      for (final m in ['Cash', 'cash', 'CASH']) {
        expect(_trip(m).isCash, isTrue, reason: m);
        expect(_trip(m).isCard, isFalse, reason: m);
      }
    });

    test('a missing method still reads as cash, as before', () {
      expect(_trip(null).isCash, isTrue);
    });
  });

  group('DropOffPaymentBanner', () {
    testWidgets('cash: collect the fare plus tip', (tester) async {
      await _pump(tester, _trip('Cash'));
      expect(find.text('Collect from customer in cash'), findsOneWidget);
      expect(find.text('£14.50'), findsOneWidget);
    });

    for (final status in ['Pending', 'Collected', 'Voided']) {
      testWidgets('card ($status): nothing to collect, no amount to ask for',
          (tester) async {
        await _pump(tester, _trip('card', status: status));
        expect(find.text('Paid by card — nothing to collect'), findsOneWidget);
        expect(find.textContaining('Collect from'), findsNothing);
        expect(find.textContaining('£'), findsNothing);
        expect(find.textContaining(RegExp('fail|declin', caseSensitive: false)),
            findsNothing);
      });
    }

    testWidgets('an unknown method says nothing rather than guess',
        (tester) async {
      await _pump(tester, _trip('Voucher'));
      expect(find.byType(Text), findsNothing);
    });
  });

  group('completedPaymentLine', () {
    test('cash names the amount collected', () {
      expect(completedPaymentLine(_trip('Cash')), 'Collected £14.50 in cash');
    });

    test('card says nothing to collect', () {
      expect(completedPaymentLine(_trip('Card', status: 'Collected')),
          'Paid by card · nothing to collect');
    });

    test('unknown method has no line', () {
      expect(completedPaymentLine(_trip('Voucher')), isNull);
    });
  });
}
