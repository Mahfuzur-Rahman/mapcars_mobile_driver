// The "Request Deletion" dialog on the Documents screen has a reason field.
// Typing into it raises the keyboard, which leaves the dialog under half the
// screen — and its content was a plain, non-scrolling Column, so on a small
// phone it overflowed and the Cancel / Submit Request buttons were squeezed
// out of reach.
//
// The dialog is pumped on its own: the Documents screen around it has an
// unrelated horizontal overflow at 360dp (see the D1 report) that would fail
// this test for the wrong reason.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/theme/app_theme.dart';
import 'package:mapcars_driver/src/core/widgets/mc.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/documents_screen.dart';

import 'support/reachability.dart';

void main() {
  for (final scale in const [1.0, 1.3]) {
    testWidgets(
        'deletion dialog: actions stay reachable with the keyboard open '
        '(text ×$scale)', (tester) async {
      final reason = TextEditingController();
      addTearDown(reason.dispose);
      bool? result;

      await pumpOnSmallPhone(
        tester,
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: McButton('Delete', full: false, onTap: () async {
                  result = await showDeletionRequestDialog(
                    context,
                    title: 'PHV driver licence',
                    fileName: 'phv-licence.pdf',
                    reason: reason,
                  );
                }),
              ),
            ),
          ),
        ),
        textScale: scale,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Request Deletion'), findsOneWidget);

      // Start typing a reason: the field takes focus and the keyboard comes up.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await showKeyboard(tester);
      // Not pumpAndSettle: a focused field's blinking cursor never settles.
      await tester.pump(const Duration(milliseconds: 400));

      expectReachableWithoutScrolling(tester, find.text('Submit Request'));
      expectReachableWithoutScrolling(tester, find.text('Cancel'));

      // And they still work.
      await tester.enterText(find.byType(TextField), 'Wrong file');
      await tester.tap(find.text('Submit Request'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, isTrue);
      expect(reason.text, 'Wrong file');
    });
  }
}
