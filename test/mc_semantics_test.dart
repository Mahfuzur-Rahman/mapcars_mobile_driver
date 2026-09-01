// Accessibility contract for the shared button widgets.
//
// Every control in mc.dart is a GestureDetector wrapping a Container — visually
// a button, but to TalkBack/VoiceOver just a box. These tests assert the three
// things a screen-reader user needs and that the raw widgets never provided:
// that it is announced as a button, that it has a label, and that a disabled
// button says so instead of looking tappable.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/widgets/mc.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('McButton announces as an enabled button with its label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(McButton('Book ride', onTap: () {})));

    final node = tester.getSemantics(find.byType(McButton));
    expect(node.label, 'Book ride');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);

    handle.dispose();
  });

  testWidgets('a button with no onTap is announced as disabled',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const McButton('Completing…')));

    // isFalse rather than none: the node must claim an enabled *state* and
    // report it as off, which is what makes a reader say "dimmed"/"disabled"
    // instead of offering it as tappable.
    final node = tester.getSemantics(find.byType(McButton));
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);

    handle.dispose();
  });

  testWidgets('the label is announced once, not twice', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(McGhostButton('Share trip', onTap: () {})));

    // The child Text carries the same string; without excludeSemantics the
    // reader would say it again as a nested node.
    final node = tester.getSemantics(find.byType(McGhostButton));
    expect(node.label, 'Share trip');
    expect(find.bySemanticsLabel('Share trip'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('McDangerButton is still a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(McDangerButton('Cancel ride', onTap: () {})));

    final node = tester.getSemantics(find.byType(McDangerButton));
    expect(node.label, 'Cancel ride');
    expect(node.flagsCollection.isButton, isTrue);

    handle.dispose();
  });

  testWidgets('McChip reports its selected state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(
      Row(children: [
        McChip('Economy', active: true, onTap: () {}),
        McChip('Comfort', onTap: () {}),
      ]),
    ));

    final on = tester.getSemantics(find.byType(McChip).first);
    expect(on.label, 'Economy');
    expect(on.flagsCollection.isSelected, Tristate.isTrue);

    final off = tester.getSemantics(find.byType(McChip).last);
    expect(off.flagsCollection.isSelected, Tristate.isFalse);

    handle.dispose();
  });

  group('McCircleButton — icon-only, so the label is all there is', () {
    testWidgets('resolves a label from the icon name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(McCircleButton('back', onTap: () {})));

      final node = tester.getSemantics(find.byType(McCircleButton));
      expect(node.label, 'Back');
      expect(node.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('an explicit semanticLabel wins over the map', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(McCircleButton('user', semanticLabel: 'Profile', onTap: () {})),
      );

      expect(tester.getSemantics(find.byType(McCircleButton)).label, 'Profile');

      handle.dispose();
    });

    testWidgets('an unmapped icon stays silent rather than reading its key',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(McCircleButton('chevR', onTap: () {})));

      // "chevR" read aloud is worse than nothing — the fix is to add the icon
      // to the map, not to leak the key.
      expect(tester.getSemantics(find.byType(McCircleButton)).label, '');

      handle.dispose();
    });
  });
}
