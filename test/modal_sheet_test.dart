// Every pop-up bottom sheet in the driver app — the six Settings pickers, the
// "add a photo" picker and the "Navigate with" handoff — goes through one
// helper, `showMcBottomSheet`.
//
// Before it, each sheet was a bare `showModalBottomSheet` with a fixed 28dp
// bottom pad and the default 9/16-of-the-screen height cap, so on a small
// phone the last option sat under a 48dp nav bar, and the six-entry Language
// list simply overflowed the sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/theme/app_theme.dart';
import 'package:mapcars_driver/src/core/widgets/mc.dart';
import 'package:mapcars_driver/src/features/account/presentation/settings_screen.dart';
import 'package:mapcars_driver/src/features/drive/services/nav_handoff.dart';

import 'support/reachability.dart';

/// The option tile that holds [text]. The Settings and photo pickers build
/// their options from private tile widgets, so match those by name — the whole
/// tile has to be reachable, not just its middle line of text.
Finder _tileOf(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => const {
            '_SettingSelectTile',
            '_SettingToggleTile',
            '_PictureSourceTile',
          }.contains(w.runtimeType.toString())),
    );

/// A screen with one button that runs [open] — for the sheets that are
/// launched from a function rather than from a screen of their own.
Widget _launcher(void Function(BuildContext) open) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: McButton('Open', full: false, onTap: () => open(context)),
          ),
        ),
      ),
    );

void main() {
  // (Settings row that opens the sheet, a line of text in its last option.)
  const settingsSheets = [
    ('Navigation app', 'In-App Navigation'),
    ('Sound & alerts', 'Speed limit warnings'),
    ('Language', 'Español'),
    ('Safety toolkit', 'Dashcam & Audio recording'),
    ('Help centre', 'Email Driver Operations'),
    ('Community & Socials', 'WhatsApp Community'),
  ];

  /// Opens the Settings sheet behind [row].
  Future<void> openSettingsSheet(
      WidgetTester tester, String row, double scale) async {
    await pumpOnSmallPhone(
      tester,
      ProviderScope(
        child: MaterialApp(
            theme: AppTheme.light, home: const DriverSettingsScreen()),
      ),
      textScale: scale,
    );
    // Reaching the row may take a scroll — that's the Settings list, not the
    // sheet under test.
    await tester.ensureVisible(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }

  for (final (row, lastOption) in settingsSheets) {
    for (final scale in const [1.0, 1.3]) {
      // Six languages at 130% text are taller than a 640dp screen: that one
      // has to scroll, and is covered separately below.
      if (row == 'Language' && scale > 1) continue;

      testWidgets(
          'Settings › $row: the last option clears a 48dp nav bar '
          '(text ×$scale)', (tester) async {
        await openSettingsSheet(tester, row, scale);

        expectReachableWithoutScrolling(tester, _tileOf(lastOption));
      });
    }
  }

  testWidgets(
      'Settings › Language at text ×1.3: the list scrolls, and its last '
      'entry scrolls clear of the nav bar', (tester) async {
    await openSettingsSheet(tester, 'Language', 1.3);

    // Taller than the screen: it used to overflow its 9/16 cap and cut the
    // list off; now the sheet takes the height it needs and scrolls the rest.
    await tester.drag(find.text('English (UK)'), const Offset(0, -600));
    await tester.pumpAndSettle();

    expectReachableWithoutScrolling(tester, _tileOf('Español'));
  });

  for (final scale in const [1.0, 1.3]) {
    testWidgets(
        'photo picker: "Choose from gallery" clears the nav bar '
        '(text ×$scale)', (tester) async {
      await pumpOnSmallPhone(
        tester,
        _launcher(showPictureSourcePicker),
        textScale: scale,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expectReachableWithoutScrolling(tester, _tileOf('Choose from gallery'));
    });
  }

  testWidgets('a sheet pads 12 + the inset below its content', (tester) async {
    await pumpOnSmallPhone(tester, _launcher(showPictureSourcePicker));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
        tester.getRect(_tileOf('Choose from gallery')).bottom, 640 - 48 - 12);
  });

  testWidgets('with no inset a sheet keeps its old 28dp bottom padding',
      (tester) async {
    await pumpOnSmallPhone(tester, _launcher(showPictureSourcePicker),
        navBarInset: 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.getRect(_tileOf('Choose from gallery')).bottom, 640 - 28);
  });

  for (final scale in const [1.0, 1.3]) {
    testWidgets(
        'showMcBottomSheet: the action sits above the open keyboard '
        '(text ×$scale)', (tester) async {
      await pumpOnSmallPhone(
        tester,
        _launcher((context) => showMcBottomSheet<void>(
              context,
              builder: (sheetContext) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const McTitle('Add a note'),
                  const SizedBox(height: 12),
                  const McField(editable: true, placeholder: 'Note'),
                  const SizedBox(height: 16),
                  McButton('Save', onTap: () => Navigator.pop(sheetContext)),
                ],
              ),
            )),
        textScale: scale,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McButton, 'Save'));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await showKeyboard(tester);
      // Not pumpAndSettle: a focused field's blinking cursor never settles.
      await tester.pump(const Duration(milliseconds: 400));

      // Lifted by the keyboard's height, measured from the sheet's own
      // context — without it Save would sit behind the keyboard.
      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McButton, 'Save'));
      expect(tester.getRect(find.widgetWithText(McButton, 'Save')).bottom,
          640 - 300 - 28);
    });
  }

  testWidgets('"Navigate with" keeps its floating card, with no double inset',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      _launcher((context) => NavHandoff.start(context,
          lat: 51.5, lng: -0.12, label: '10 Downing St')),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final waze = find
        .ancestor(of: find.text('Waze'), matching: find.byType(Container))
        .first;
    expectReachableWithoutScrolling(tester, waze);
    // The card floats 12dp above the nav bar: 48 inset + 12 card margin +
    // 12 card padding + 8 under the last tile. A second inset would add 48.
    expect(tester.getRect(waze).bottom, 640 - 48 - 12 - 12 - 8);
  });
}
