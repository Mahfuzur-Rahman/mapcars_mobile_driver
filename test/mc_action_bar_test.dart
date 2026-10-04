// McActionBar pins a full-screen page's primary action below its scrolling
// content, so the button is on screen without a scroll — on a small phone,
// with large text, and with the keyboard up.
//
// It reads the bottom system inset itself, so it must also not count that
// inset twice when an ancestor SafeArea has already applied it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/theme/app_theme.dart';
import 'package:mapcars_driver/src/core/widgets/mc.dart';

import 'support/reachability.dart';

/// The intended page shape: header, scrolling content, pinned bar — with a
/// text field and enough content that the page cannot fit on a small phone.
Widget _page({bool safeArea = false, bool safeAreaBottom = true}) {
  final column = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.all(22),
        child: McTitle('Vehicle details'),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const McField(editable: true, placeholder: 'Registration'),
              for (var i = 0; i < 12; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: McField(placeholder: 'Field $i'),
                ),
            ],
          ),
        ),
      ),
      McActionBar(children: [
        McButton('Save', onTap: () {}),
        McGhostButton('Cancel', onTap: () {}),
      ]),
    ],
  );
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      backgroundColor: Brand.bg,
      body: safeArea ? SafeArea(bottom: safeAreaBottom, child: column) : column,
    ),
  );
}

void main() {
  for (final scale in const [1.0, 1.3]) {
    testWidgets('both actions clear a 48dp nav bar (text ×$scale)',
        (tester) async {
      await pumpOnSmallPhone(tester, _page(), textScale: scale);

      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McButton, 'Save'));
      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McGhostButton, 'Cancel'));
    });

    testWidgets('both actions sit above the open keyboard (text ×$scale)',
        (tester) async {
      await pumpOnSmallPhone(tester, _page(), textScale: scale);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await showKeyboard(tester);

      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McButton, 'Save'));
      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McGhostButton, 'Cancel'));
      // Flush on the keyboard's terms, not the nav bar's: nothing below the
      // bar's own 12dp pad.
      expect(tester.getRect(find.byType(McActionBar)).bottom, 640 - 300);
      expect(
          tester.getRect(find.widgetWithText(McGhostButton, 'Cancel')).bottom,
          640 - 300 - 12);
    });
  }

  testWidgets('pads 12 + the inset and paints under the nav bar',
      (tester) async {
    await pumpOnSmallPhone(tester, _page());

    expect(tester.getRect(find.byType(McActionBar)).bottom, 640);
    expect(tester.getRect(find.widgetWithText(McGhostButton, 'Cancel')).bottom,
        640 - 48 - 12);
  });

  testWidgets('SafeArea(bottom: false) around the page: same, no double inset',
      (tester) async {
    await pumpOnSmallPhone(
        tester, _page(safeArea: true, safeAreaBottom: false));

    expect(tester.getRect(find.byType(McActionBar)).bottom, 640);
    expect(tester.getRect(find.widgetWithText(McGhostButton, 'Cancel')).bottom,
        640 - 48 - 12);
  });

  testWidgets('inside a full SafeArea the inset is not counted twice',
      (tester) async {
    await pumpOnSmallPhone(tester, _page(safeArea: true));

    // SafeArea already lifted the whole page by 48 — the bar adds only its own
    // 12, not another 48.
    expect(tester.getRect(find.byType(McActionBar)).bottom, 640 - 48);
    expect(tester.getRect(find.widgetWithText(McGhostButton, 'Cancel')).bottom,
        640 - 48 - 12);
  });

  testWidgets('stacks its buttons with a 10dp gap', (tester) async {
    await pumpOnSmallPhone(tester, _page(), navBarInset: 0);

    final save = tester.getRect(find.widgetWithText(McButton, 'Save'));
    final cancel = tester.getRect(find.widgetWithText(McGhostButton, 'Cancel'));
    expect(cancel.top - save.bottom, 10);
    expect(save.left, 22);
    expect(save.right, 360 - 22);
  });

  testWidgets('refuses more than two buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: McActionBar(children: [
        McButton('A', onTap: () {}),
        McButton('B', onTap: () {}),
        McButton('C', onTap: () {}),
      ]),
    ));
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('can be const', (tester) async {
    // A const-constructor assert on the list length would fail to compile here.
    await tester.pumpWidget(const MaterialApp(
      home: McActionBar(children: [McButton('Saving…')]),
    ));
    expect(find.text('Saving…'), findsOneWidget);
  });
}
