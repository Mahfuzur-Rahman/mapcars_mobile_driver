// Weekly statements.
//
// A statement is the one screen a driver checks against their bank, so the
// failures that matter are quiet ones: a week labelled a day early because the
// phone isn't on London time, a penny lost to a double, or a negative net read
// as money coming in. Each is pinned below.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/utils/money.dart';
import 'package:mapcars_driver/src/core/utils/uk_time.dart';
import 'package:mapcars_driver/src/features/account/models/statement.dart';
import 'package:mapcars_driver/src/features/account/presentation/statements_screen.dart';
import 'package:mapcars_driver/src/features/account/services/statement_service.dart';

Map<String, dynamic> _summary({
  String start = '2026-09-06T23:00:00Z',
  String end = '2026-09-13T23:00:00Z',
  int net = 4250,
  String status = 'Issued',
}) =>
    {
      'id': 's1',
      'driverId': 'd1',
      'driverName': 'Test Driver',
      'periodStartUtc': start,
      'periodEndUtc': end,
      'tripCount': 3,
      'grossFaresPence': 6000,
      'tipsPence': 300,
      'commissionPence': 900,
      'driverEarningsPence': 5400,
      'cardPayablePence': 4700,
      'cashCommissionOwedPence': 450,
      'netPence': net,
      'status': status,
      'createdAtUtc': '2026-09-14T00:05:00Z',
    };

void main() {
  group('UK time', () {
    test('BST runs from the last Sunday of March to the last of October', () {
      expect(isBritishSummerTime(DateTime.utc(2026, 3, 29, 0, 59)), isFalse);
      expect(isBritishSummerTime(DateTime.utc(2026, 3, 29, 1)), isTrue);
      expect(isBritishSummerTime(DateTime.utc(2026, 10, 25, 0, 59)), isTrue);
      expect(isBritishSummerTime(DateTime.utc(2026, 10, 25, 1)), isFalse);
      expect(isBritishSummerTime(DateTime.utc(2026, 1, 15)), isFalse);
    });

    test('a BST Monday midnight is 23:00 UTC the Sunday before', () {
      final uk = toUkTime(DateTime.utc(2026, 9, 6, 23));
      expect([uk.year, uk.month, uk.day, uk.hour], [2026, 9, 7, 0]);
    });
  });

  group('Statement.periodLabel', () {
    test('summer week: Mon–Sun in UK dates, not UTC', () {
      expect(Statement.fromJson(_summary()).periodLabel,
          'Mon 7 Sep – Sun 13 Sep');
    });

    test('winter week', () {
      final s = Statement.fromJson(_summary(
          start: '2026-01-05T00:00:00Z', end: '2026-01-12T00:00:00Z'));
      expect(s.periodLabel, 'Mon 5 Jan – Sun 11 Jan');
    });

    test('the week the clocks go back', () {
      final s = Statement.fromJson(_summary(
          start: '2026-10-18T23:00:00Z', end: '2026-10-26T00:00:00Z'));
      expect(s.periodLabel, 'Mon 19 Oct – Sun 25 Oct');
    });
  });

  group('parsing', () {
    test('money is integer pence', () {
      final s = Statement.fromJson(_summary());
      expect(s.netPence, isA<int>());
      expect(s.netPence, 4250);
      expect(s.cashCommissionOwedPence, 450);
      expect(s.isSettled, isFalse);
      expect(Statement.fromJson(_summary(status: 'Settled')).isSettled, isTrue);
    });

    test('detail lines keep the sign of amountPence', () {
      final d = StatementDetail.fromJson({
        'summary': _summary(),
        'lines': [
          {
            'tripId': 't1',
            'completedAtUtc': '2026-09-08T17:38:00Z',
            'paymentMethod': 'Cash',
            'farePence': 2000,
            'tipPence': 0,
            'commissionPence': 300,
            'driverEarningsPence': 1700,
            'amountPence': -300,
          },
          {
            'tripId': 't2',
            'completedAtUtc': '2026-09-09T09:00:00Z',
            'paymentMethod': 'Card',
            'farePence': 2000,
            'tipPence': 200,
            'commissionPence': 300,
            'driverEarningsPence': 1700,
            'amountPence': 1900,
          },
        ],
      });
      expect(d.lines.map((l) => l.amountPence), [-300, 1900]);
      expect(d.lines[0].isCash, isTrue);
      expect(d.lines[0].whenLabel, 'Tue 8 Sep · 6:38 PM'); // BST
      expect(d.lines[0].detailLabel, 'Cash · you collected £20.00');
      expect(d.lines[1].detailLabel, 'Card · fare £20.00 + £2.00 tip');
    });
  });

  group('net', () {
    test('positive: Mapcars pays', () {
      expect(netHeadline(4250), 'Mapcars pays you £42.50');
      expect(netDirection(4250), NetDirection.mapcarsPays);
    });

    test('negative: the driver owes cash commission', () {
      expect(netHeadline(-450),
          'You owe Mapcars £4.50 commission on cash trips');
      expect(netDirection(-450), NetDirection.driverOwes);
    });

    test('zero: nothing due', () {
      expect(netDirection(0), NetDirection.nothingDue);
      expect(netHeadline(0), contains('Nothing due'));
    });

    test('signed amounts', () {
      expect(formatSignedGbp(1900), '+£19.00');
      expect(formatSignedGbp(-300), '−£3.00');
      expect(formatSignedGbp(0), '£0.00');
    });
  });

  group('StatementsScreen', () {
    Future<void> pump(WidgetTester tester, List<Statement> list) =>
        tester.pumpWidget(ProviderScope(
          overrides: [statementsProvider.overrideWith((ref) async => list)],
          child: const MaterialApp(home: StatementsScreen()),
        ));

    testWidgets('empty: says when the first one arrives', (tester) async {
      await pump(tester, const []);
      await tester.pumpAndSettle();
      expect(
        find.text(
            'Your first statement appears the Monday after your first completed week.'),
        findsOneWidget,
      );
    });

    testWidgets('lists each week with who pays whom', (tester) async {
      await pump(tester, [
        Statement.fromJson(_summary()),
        Statement.fromJson(_summary(net: -450, status: 'Settled')),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Mapcars pays you £42.50'), findsOneWidget);
      expect(find.text('You owe Mapcars £4.50 commission on cash trips'),
          findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('Issued'), findsOneWidget);
    });
  });
}
