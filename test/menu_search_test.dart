// The menu drawer's search box: what it finds, in what order, and — in a real
// (non-debug) build — that it can never surface a prototype walk-through step.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/router/app_router.dart';
import 'package:mapcars_driver/src/core/theme/app_theme.dart';
import 'package:mapcars_driver/src/core/widgets/menu_search.dart';
import 'package:mapcars_driver/src/core/widgets/screen_stepper.dart';

const _routes = [
  StepRoute('/a', 'Payment', icon: 'card', keywords: ['card']),
  StepRoute('/b', 'Trip history', icon: 'clock', keywords: ['receipt', 'payment slips']),
  StepRoute('/c', 'Account', icon: 'user', keywords: ['help']),
];

List<String> _paths(List<MenuHit> hits) => [for (final h in hits) h.route.path];

/// What a release build's search box looks through.
final _releasePool = kDriverFlow.where((r) => r.isSearchable).toList();

void main() {
  test('an empty query finds nothing, so the plain menu shows', () {
    expect(searchMenu(_routes, ''), isEmpty);
    expect(searchMenu(_routes, '   '), isEmpty);
  });

  test('a label match outranks a keyword match, case-insensitively', () {
    expect(_paths(searchMenu(_routes, 'PAY')), ['/a', '/b']);
  });

  test('a word inside the label matches', () {
    expect(_paths(searchMenu(_routes, 'hist')), ['/b']);
  });

  test('a keyword match says which keyword found it', () {
    final hits = searchMenu(_routes, 'help');
    expect(_paths(hits), ['/c']);
    expect(hits.single.matchedKeyword, 'help');
  });

  test('route paths only match in the dev walk-through', () {
    expect(searchMenu(_routes, '/c'), isEmpty);
    expect(_paths(searchMenu(_routes, '/c', matchPath: true)), ['/c']);
  });

  group('release build', () {
    test('menu shows the user destinations, including Edit profile and Change password', () {
      expect(
        [for (final r in kDriverFlow.where((r) => r.isMenuItem)) r.label],
        ['Home', 'Messages', 'Earnings', 'Payouts', 'Statements', 'Trip history',
         'Documents',
         'Profile', 'Edit profile', 'Settings', 'Change password'],
      );
    });

    test('search never reaches a prototype step', () {
      for (final q in ['request', 'driving', 'arrived', 'trip complete', 'screens', 'review']) {
        for (final hit in searchMenu(_releasePool, q)) {
          expect(hit.route.icon, isNotNull, reason: '"$q" found ${hit.route.path}');
        }
      }
      expect(searchMenu(_releasePool, 'driving'), isEmpty);
    });

    test('everyday words land on the right page', () {
      expect(searchMenu(_releasePool, 'password').first.route.path,
          '/settings/change-password');
      expect(searchMenu(_releasePool, 'language').first.route.path, '/settings');
      expect(searchMenu(_releasePool, 'language').first.matchedKeyword, 'language');
      expect(searchMenu(_releasePool, 'licence').first.route.path, '/documents');
      expect(searchMenu(_releasePool, 'bank').first.route.path, '/payouts');
      expect(searchMenu(_releasePool, 'invoice').first.route.path, '/statements');
    });

    test('vehicle search finds the tier page and Profile, never the blank add-vehicle form', () {
      final paths = _paths(searchMenu(_releasePool, 'vehicle'));
      expect(paths, ['/profile/tier', '/profile']);
      expect(searchMenu(_releasePool, 'car').map((h) => h.route.path),
          isNot(contains('/profile/vehicle')));
    });

    test('Vehicle tier is search-only', () {
      final tier = kDriverFlow.firstWhere((r) => r.path == '/profile/tier');
      expect(tier.isSearchable, isTrue);
      expect(tier.isMenuItem, isFalse);
    });
  });

  testWidgets('typing filters the drawer, explains keyword hits, and clears',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(devDrawerOpenProvider.notifier).state = true;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ScreenStepper(
          routes: _routes,
          current: '/a',
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'help');
    await tester.pump();
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Payment'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Nothing matches “zzz”'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Trip history'), findsOneWidget);

    // Closing the drawer resets the search for next time.
    await tester.enterText(find.byType(TextField), 'help');
    container.read(devDrawerOpenProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.text('help'), findsNothing);
  });
}
