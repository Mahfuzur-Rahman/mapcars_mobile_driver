// Test support: "can the driver reach this button without scrolling?"
//
// The client's complaint was that bottom buttons were sometimes hard to tap or
// needed a scroll to find. Both had the same causes: content drawn under the
// Android 15 edge-to-edge nav bar / iOS home indicator (taps swallowed by the
// system), and primary actions living at the end of a scroll view. These two
// helpers put a screen on the phone that shows those problems most — a small
// 360×640 dp handset with a 48 dp 3-button nav bar — and then assert that a
// widget is fully on screen and tappable *without* scrolling anything.
//
// Usage:
//
//   await pumpOnSmallPhone(
//       tester, MaterialApp(theme: AppTheme.light, home: MyScreen()),
//       textScale: 1.3);
//   expectReachableWithoutScrolling(tester, find.text('Start trip'));
//
//   // A screen with a text field: open the keyboard and check again.
//   await showKeyboard(tester);
//   expectReachableWithoutScrolling(tester, find.text('Save'));

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logical size of the small phone every reachability test runs on.
const Size kSmallPhone = Size(360, 640);

/// Height of Android's 3-button navigation bar — the largest bottom system
/// inset in common use (the iOS home indicator is 34).
const double kNavBarInset = 48;

/// Height of an open soft keyboard on the small phone.
const double kKeyboardHeight = 300;

/// A realistic pixel ratio, so a physical/logical mix-up in a widget would
/// show up here rather than on a real phone.
const double _dpr = 3;

/// Puts [app] on a 360×640 dp phone with a [navBarInset] system nav bar at the
/// given [textScale], then pumps it.
///
/// [app] is pumped as-is — pass the whole tree (`MaterialApp`, provider scope
/// and all) exactly as a normal widget test would. Give the `MaterialApp`
/// `theme: AppTheme.light`: this loads the app's bundled Nunito, and the theme
/// is what selects it. Without it text falls back to the test font, whose
/// glyphs are 1em squares — far wider and shorter than real text — so a
/// layout can pass here and still fail on a phone, or the reverse.
///
/// The nav bar is set on both `padding` and `viewPadding`, because that is what
/// Android reports with no keyboard up. With [keyboardOpen], the keyboard
/// condition from [showKeyboard] is applied from the first frame instead.
///
/// Everything is reset when the test ends.
Future<void> pumpOnSmallPhone(
  WidgetTester tester,
  Widget app, {
  double textScale = 1.0,
  double navBarInset = kNavBarInset,
  bool keyboardOpen = false,
}) async {
  final view = tester.view;
  view.devicePixelRatio = _dpr;
  view.physicalSize = kSmallPhone * _dpr;
  view.viewPadding = FakeViewPadding(bottom: navBarInset * _dpr);
  view.padding = FakeViewPadding(bottom: navBarInset * _dpr);
  view.viewInsets = FakeViewPadding.zero;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await _loadNunito(tester);

  if (keyboardOpen) _applyKeyboard(tester);

  await tester.pumpWidget(app);
  await tester.pump();
}

bool _nunitoLoaded = false;

/// Registers the app's bundled Nunito with the engine, once per test file.
Future<void> _loadNunito(WidgetTester tester) async {
  if (_nunitoLoaded) return;
  // Real I/O: run it outside the test's fake-async zone or it never completes.
  await tester.runAsync(() async {
    final loader = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await loader.load();
  });
  _nunitoLoaded = true;
}

/// Opens the soft keyboard on the current test view and pumps a frame.
///
/// Mirrors what Android reports under `adjustResize`: `viewInsets.bottom` is
/// the keyboard, and `padding.bottom` drops to 0 because the keyboard now
/// covers the nav bar. `viewPadding` keeps the nav bar — it always reports the
/// raw system inset.
Future<void> showKeyboard(WidgetTester tester) async {
  _applyKeyboard(tester);
  await tester.pump();
}

void _applyKeyboard(WidgetTester tester) {
  tester.view.viewInsets =
      const FakeViewPadding(bottom: kKeyboardHeight * _dpr);
  tester.view.padding = FakeViewPadding.zero;
}

/// The lowest y (logical px) a tappable widget may reach on the current view.
///
/// Below this sits either the system nav bar or the keyboard. The keyboard's
/// inset is measured from the bottom of the screen and so already covers the
/// nav bar beneath it — taking the larger of the two (not their sum) is what
/// keeps an open keyboard from counting the nav bar twice. When only one is
/// present this is exactly `height − viewPadding.bottom − viewInsets.bottom`.
double visibleBottom(WidgetTester tester) {
  final view = tester.view;
  final height = view.physicalSize.height / view.devicePixelRatio;
  final navBar = view.viewPadding.bottom / view.devicePixelRatio;
  final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
  return height - math.max(navBar, keyboard);
}

/// Asserts [finder] is fully inside the visible area and can be tapped as the
/// screen stands — with no scrolling performed.
///
/// Two checks, because each misses what the other catches:
///  • its rect must lie within `[0, visibleBottom]` — tests have no system bar
///    to swallow a tap, so a button half under the nav bar would otherwise
///    still "work" here;
///  • it must be hit-testable at its centre and near its top and bottom edges —
///    a button clipped by a scroll viewport or covered by another widget lays
///    out at a perfectly good rect yet can't be tapped.
void expectReachableWithoutScrolling(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);

  final rect = tester.getRect(finder);
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final bottom = visibleBottom(tester);
  const epsilon = 0.01;

  expect(rect.top, greaterThanOrEqualTo(-epsilon),
      reason: '$finder starts above the top of the screen ($rect)');
  expect(rect.left, greaterThanOrEqualTo(-epsilon),
      reason: '$finder starts left of the screen ($rect)');
  expect(rect.right, lessThanOrEqualTo(width + epsilon),
      reason: '$finder runs off the right of the screen ($rect)');
  expect(rect.bottom, lessThanOrEqualTo(bottom + epsilon),
      reason: '$finder reaches y=${rect.bottom.toStringAsFixed(1)}, below the '
          'visible area (y ≤ ${bottom.toStringAsFixed(1)}) — it is under the '
          'nav bar / keyboard, or needs a scroll to reach');

  for (final at in const [
    Alignment.center,
    Alignment(0, -0.8),
    Alignment(0, 0.8),
  ]) {
    expect(finder.hitTestable(at: at), findsOneWidget,
        reason: '$finder is laid out on screen but a tap at $at would not '
            'reach it (clipped by a scroll view or covered by something)');
  }
}
