// The Drive / Earnings / Account tab bar under the account screens.
//
// It was a fixed 84dp with 18dp of bottom padding, copied into three screens.
// On a phone with a 48dp nav bar the labels landed under the system bar, so a
// tap on "Earnings" could be swallowed by the OS. One shared, inset-aware bar
// replaces the three copies.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/theme/app_theme.dart';
import 'package:mapcars_driver/src/core/widgets/driver_tab_bar.dart';
import 'package:mapcars_driver/src/features/account/presentation/settings_screen.dart';

import 'support/reachability.dart';

void main() {
  for (final scale in const [1.0, 1.3]) {
    testWidgets('Settings: every tab clears a 48dp nav bar (text ×$scale)',
        (tester) async {
      await pumpOnSmallPhone(
        tester,
        ProviderScope(
          child: MaterialApp(
              theme: AppTheme.light, home: const DriverSettingsScreen()),
        ),
        textScale: scale,
      );

      expect(find.byType(DriverTabBar), findsOneWidget);
      for (final label in const ['Drive', 'Earnings', 'Account']) {
        expectReachableWithoutScrolling(
            tester,
            find.descendant(
                of: find.byType(DriverTabBar), matching: find.text(label)));
      }
    });
  }

  Widget host(DriverTab active) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: DriverTabBar(active: active),
        ),
      );

  testWidgets('with no inset it keeps the original 84dp look', (tester) async {
    await pumpOnSmallPhone(tester, host(DriverTab.earnings), navBarInset: 0);

    expect(tester.getRect(find.byType(DriverTabBar)).height, 84);
    // Labels sit in the same place the old bar drew them: the content band is
    // the 66dp above an 18dp bottom pad.
    expect(tester.getRect(find.text('Earnings')).bottom,
        lessThanOrEqualTo(640 - 18));
  });

  // The bottom padding is max(18, inset), not 18 + inset: the tab band is 66dp
  // and the 18dp of breathing room the design always had doubles as the
  // clearance, so a 34dp iPhone home indicator doesn't leave a 52dp dead strip.
  testWidgets('with a 48dp nav bar the bottom pad is the inset itself',
      (tester) async {
    await pumpOnSmallPhone(tester, host(DriverTab.earnings), navBarInset: 0);
    final bare = tester.getRect(find.text('Earnings'));

    await pumpOnSmallPhone(tester, host(DriverTab.earnings));
    expect(tester.getRect(find.byType(DriverTabBar)).height, 66 + 48);
    // Same label, same distance from the top of the bar — lifted by the 30dp
    // by which the inset exceeds the usual 18dp pad.
    expect(tester.getRect(find.text('Earnings')),
        bare.shift(const Offset(0, -30.0)));
  });

  testWidgets('a 34dp home indicator gives 100dp, not 118dp', (tester) async {
    await pumpOnSmallPhone(tester, host(DriverTab.earnings), navBarInset: 34);
    expect(tester.getRect(find.byType(DriverTabBar)).height, 66 + 34);
    expect(tester.getRect(find.text('Earnings')).bottom,
        lessThanOrEqualTo(640 - 34));
  });

  testWidgets('an inset under 18dp changes nothing (still 84dp)',
      (tester) async {
    await pumpOnSmallPhone(tester, host(DriverTab.earnings), navBarInset: 10);
    expect(tester.getRect(find.byType(DriverTabBar)).height, 84);
  });

  testWidgets('highlights the active tab and announces it as selected',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnSmallPhone(tester, host(DriverTab.account));

    expect(tester.getSemantics(find.text('Account')).flagsCollection.isSelected,
        Tristate.isTrue);
    expect(tester.getSemantics(find.text('Drive')).flagsCollection.isSelected,
        Tristate.isFalse);
    handle.dispose();
  });
}
