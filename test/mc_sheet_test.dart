// McSheet is the rounded sheet at the bottom of every driving-flow map screen
// (home, request card, nav to pickup, arrived, driving, route preview), and its
// buttons are what a driver reaches for with the phone in a mount.
//
// It used to pad its bottom with a fixed 28 dp. With Android 15 edge-to-edge a
// 3-button nav bar is 48 dp tall, so the lower part of the last button sat
// under the system bar and taps on it were swallowed. These tests pin the
// inset-aware padding, the pinned footer, and the height cap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/theme/app_theme.dart';
import 'package:mapcars_driver/src/core/widgets/mc.dart';

import 'support/reachability.dart';

/// A map screen in miniature: the sheet aligned to the bottom of a Stack, the
/// way every call site places it.
Widget _mapScreen(Widget sheet) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Brand.bg)),
            Align(alignment: Alignment.bottomCenter, child: sheet),
          ],
        ),
      ),
    );

Widget _tallBody() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 40; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Line $i'),
          ),
      ],
    );

void main() {
  for (final scale in const [1.0, 1.3]) {
    testWidgets(
        'without a footer, the last child clears a 48dp nav bar (text ×$scale)',
        (tester) async {
      await pumpOnSmallPhone(
        tester,
        _mapScreen(McSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const McTitle("You're offline", size: 18),
              const SizedBox(height: 14),
              McButton('Go online', onTap: () {}),
            ],
          ),
        )),
        textScale: scale,
      );

      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McButton, 'Go online'));
    });
  }

  testWidgets('with no system inset the sheet keeps its 28dp bottom padding',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      _mapScreen(McSheet(child: McButton('Go online', onTap: () {}))),
      navBarInset: 0,
    );

    expect(tester.getRect(find.byType(McButton)).bottom, 640 - 28);
  });

  testWidgets('with a 48dp nav bar the bottom padding is 12 + the inset',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      _mapScreen(McSheet(child: McButton('Go online', onTap: () {}))),
    );

    // The sheet's paper still runs to the bottom edge, under the nav bar…
    expect(tester.getRect(find.byType(McSheet)).bottom, 640);
    // …but its content stops 12dp above the bar.
    expect(tester.getRect(find.byType(McButton)).bottom, 640 - 48 - 12);
  });

  for (final scale in const [1.0, 1.3]) {
    testWidgets(
        'a footer stays on screen below a body too tall to fit (text ×$scale)',
        (tester) async {
      await pumpOnSmallPhone(
        tester,
        _mapScreen(McSheet(
          footer: McButton('Accept', onTap: () {}),
          child: _tallBody(),
        )),
        textScale: scale,
      );

      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McButton, 'Accept'));

      // The sheet stops at ~85% of the screen, leaving the top of the map (and
      // its floating controls) uncovered…
      expect(tester.getRect(find.byType(McSheet)).height,
          lessThanOrEqualTo(640 * 0.85 + 0.01));

      // …and the body scrolls inside it while the footer stays put.
      final before = tester.getRect(find.byType(McButton));
      await tester.drag(find.text('Line 0'), const Offset(0, -3000));
      await tester.pump();
      expect(find.text('Line 39').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byType(McButton)), before);
      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McButton, 'Accept'));
    });
  }

  testWidgets('maxHeight caps a tall sheet but never stretches a short one',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      _mapScreen(McSheet(maxHeight: 300, child: _tallBody())),
    );
    expect(tester.getRect(find.byType(McSheet)).height, 300);

    await pumpOnSmallPhone(
      tester,
      _mapScreen(const McSheet(maxHeight: 300, child: Text('Short'))),
    );
    expect(tester.getRect(find.byType(McSheet)).height, lessThan(300));
  });

  testWidgets('a body that fits does not scroll', (tester) async {
    await pumpOnSmallPhone(
      tester,
      _mapScreen(McSheet(
        footer: McButton('Accept', onTap: () {}),
        child: const Text('Pickup · Alex'),
      )),
    );

    final scrollable = tester.state<ScrollableState>(find.descendant(
        of: find.byType(McSheet), matching: find.byType(Scrollable)));
    expect(scrollable.position.maxScrollExtent, 0);
  });
}
