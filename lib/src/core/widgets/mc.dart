import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../router/nav.dart';
import '../theme/brand.dart';
import '../theme/mc_icons.dart';
import 'drawer_state.dart';

export '../theme/brand.dart';
export '../theme/mc_icons.dart';
export 'drawer_state.dart';

/// Text style helper (inherits Nunito from the theme's DefaultTextStyle).
TextStyle tw(FontWeight w, double size, [Color color = Brand.ink, double? ls]) =>
    TextStyle(fontWeight: w, fontSize: size, color: color, letterSpacing: ls);

/// Heading — bold, tight tracking.
class McTitle extends StatelessWidget {
  const McTitle(this.text, {super.key, this.size = 20, this.color = Brand.ink, this.align});
  final String text;
  final double size;
  final Color color;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: align,
      style: tw(FontWeight.w900, size, color, -0.3));
}

/// Input field. Two modes:
///  • display/button — shows [value] or [placeholder]; taps fire [onTap]
///    (used as a navigation button, e.g. Home's "Where to?").
///  • editable — pass [editable] true (and optionally a [controller]) to get a
///    real, typeable TextField with the same styling.
class McField extends StatefulWidget {
  const McField({
    super.key,
    this.icon,
    this.placeholder,
    this.value,
    this.active = false,
    this.dot,
    this.width,
    this.onTap,
    this.editable = false,
    this.controller,
    this.keyboardType,
    this.obscure = false,
    this.autofocus = false,
    this.onChanged,
    this.suffix,
    this.scrollPadding = const EdgeInsets.all(20),
  });
  final String? icon;
  final String? placeholder;
  final String? value;
  final bool active;
  final Color? dot;
  final double? width;
  final VoidCallback? onTap;

  // Editable mode
  final bool editable;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  /// How much room the field keeps around itself when focusing scrolls it into
  /// view (editable mode). Raise the bottom value when something sits below the
  /// field that must stay visible above the keyboard - e.g. a button, with a
  /// pinned McActionBar under the scroll body.
  final EdgeInsets scrollPadding;

  @override
  State<McField> createState() => _McFieldState();
}

class _McFieldState extends State<McField> {
  TextEditingController? _internal;
  final FocusNode _focus = FocusNode();

  TextEditingController get _controller {
    if (widget.controller != null) return widget.controller!;
    return _internal ??= TextEditingController(text: widget.value ?? '');
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _internal?.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlight = widget.active || (widget.editable && _focus.hasFocus);
    final hasValue = widget.value != null && widget.value!.isNotEmpty;

    final Widget inner = widget.editable
        ? TextField(
            controller: _controller,
            focusNode: _focus,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscure,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            scrollPadding: widget.scrollPadding,
            cursorColor: Brand.blue,
            style: tw(FontWeight.w700, 15, Brand.ink),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: widget.placeholder,
              hintStyle: tw(FontWeight.w600, 15, Brand.faint),
            ),
          )
        : Text(
            hasValue ? widget.value! : (widget.placeholder ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tw(hasValue ? FontWeight.w700 : FontWeight.w600, 15,
                hasValue ? Brand.ink : Brand.faint),
          );

    return GestureDetector(
      onTap: widget.editable ? null : widget.onTap,
      child: Container(
        width: widget.width,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Brand.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? Brand.blue : Brand.line, width: 1.5),
          boxShadow: highlight
              ? [BoxShadow(color: Brand.blue.withValues(alpha: 0.13), blurRadius: 0, spreadRadius: 3)]
              : null,
        ),
        child: Row(
          children: [
            if (widget.dot != null) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.dot, shape: BoxShape.circle)),
              const SizedBox(width: 10),
            ],
            if (widget.icon != null) ...[Ico(widget.icon!, size: 20, color: Brand.sub), const SizedBox(width: 10)],
            Expanded(child: inner),
            if (widget.suffix != null) ...[const SizedBox(width: 8), widget.suffix!],
          ],
        ),
      ),
    );
  }
}

enum BtnKind { blue, green, grad }

/// Gives a hand-built tappable the semantics a real button would carry.
///
/// Every control in this file is a `GestureDetector` wrapping a `Container` —
/// visually a button, but to TalkBack/VoiceOver just a box with some text in
/// it, never announced as tappable and never reporting when it is disabled.
///
/// [excludeSemantics] is deliberate: the child usually contains the same string
/// as [label], and without it the label is announced twice.
Widget mcTapSemantics({
  required String? label,
  required bool enabled,
  bool? selected,
  required Widget child,
}) =>
    Semantics(
      button: true,
      enabled: enabled,
      label: label,
      selected: selected,
      excludeSemantics: true,
      child: child,
    );

class McButton extends StatelessWidget {
  const McButton(this.label, {super.key, this.icon, this.kind = BtnKind.blue, this.full = true, this.onTap, this.height = 54});
  final String label;
  final String? icon;
  final BtnKind kind;
  final bool full;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Gradient? g = switch (kind) {
      BtnKind.green => Brand.gradGreen,
      BtnKind.grad => Brand.grad,
      BtnKind.blue => null,
    };
    // Glow tint follows the button's own colour.
    final Color glow = kind == BtnKind.green ? Brand.green : Brand.blue;
    return mcTapSemantics(
      label: label,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: full ? double.infinity : null,
          height: height,
          padding: full ? null : const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: g == null ? Brand.blue : null,
            gradient: g,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(
            mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Ico(icon!, size: 20, color: Colors.white), const SizedBox(width: 8)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tw(FontWeight.w800, 16, Colors.white))),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small count bubble pinned to the top-right of [child].
///
/// Nothing is drawn at zero, so callers can pass a live count without guarding.
/// The bubble is [ExcludeSemantics] — a screen reader gets the count from the
/// wrapped control's own label instead (see `McGhostButton.semanticLabel`),
/// because a bare "3" announced next to a button is not information.
class McBadge extends StatelessWidget {
  const McBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -5,
          right: -5,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Brand.paper, width: 2),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: tw(FontWeight.w900, 11, Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Secondary (outline) button.
class McGhostButton extends StatelessWidget {
  const McGhostButton(this.label,
      {super.key,
      this.icon,
      this.full = true,
      this.onTap,
      this.height = 54,
      this.semanticLabel});
  final String label;
  final String? icon;
  final bool full;
  final VoidCallback? onTap;
  final double height;

  /// Overrides what a screen reader announces. Used where the visible label
  /// alone understates the control — an unread count, for instance.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => mcTapSemantics(
        label: semanticLabel ?? label,
        enabled: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: full ? double.infinity : null,
            height: height,
            padding: full ? null : const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Brand.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Brand.line, width: 1.5),
            ),
            child: Row(
              mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Ico(icon!, size: 20, color: Brand.ink), const SizedBox(width: 8)],
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tw(FontWeight.w800, 16, Brand.ink))),
              ],
            ),
          ),
        ),
      );
}

/// Full-width outline button for destructive actions (e.g. logout).
class McDangerButton extends StatelessWidget {
  const McDangerButton(this.label, {super.key, this.icon, this.full = true, this.onTap, this.height = 54});
  final String label;
  final String? icon;
  final bool full;
  final VoidCallback? onTap;
  final double height;

  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) => mcTapSemantics(
        label: label,
        enabled: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: full ? double.infinity : null,
            height: height,
            padding: full ? null : const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _red.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Row(
              mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Ico(icon!, size: 20, color: _red), const SizedBox(width: 8)],
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tw(FontWeight.w800, 16, _red))),
              ],
            ),
          ),
        ),
      );
}

class McChip extends StatelessWidget {
  const McChip(this.label, {super.key, this.icon, this.active = false, this.onTap});
  final String label;
  final String? icon;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => mcTapSemantics(
        label: label,
        enabled: onTap != null,
        // Chips are filters, so their on/off state has to be announced too —
        // "Economy, selected" rather than just "Economy".
        selected: active,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? Brand.blue : Brand.paper,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: active ? Brand.blue : Brand.line, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Ico(icon!, size: 16, color: active ? Colors.white : Brand.sub), const SizedBox(width: 6)],
              Text(label, style: tw(FontWeight.w700, 13, active ? Colors.white : Brand.ink)),
            ]),
          ),
        ),
      );
}

class McCard extends StatelessWidget {
  const McCard({super.key, required this.child, this.padding = 16, this.color, this.border, this.dashed = false});
  final Widget child;
  final double padding;
  final Color? color;
  final Color? border;
  final bool dashed;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color ?? Brand.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border ?? Brand.line),
          boxShadow: Brand.cardShadow,
        ),
        child: child,
      );
}

class McAvatar extends StatelessWidget {
  const McAvatar({super.key, this.size = 44, this.color = Brand.fillDeep, this.icon = 'user'});
  final double size;
  final Color color;
  final String icon;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: Ico(icon, size: size * 0.5, color: Colors.white)),
      );
}

/// Bottom padding for anything drawn flush with the bottom of the screen: the
/// design's 28dp where there is no system inset, otherwise 12dp clear of the
/// nav bar / home indicator.
///
/// Android 15 forces edge-to-edge, so a 3-button nav bar (48dp) sits *over*
/// the app — a fixed 28 left the lower half of the last button under it, and
/// taps there were swallowed by the system.
double _bottomPadding(BuildContext context) =>
    math.max(28, 12 + MediaQuery.paddingOf(context).bottom);

/// Rounded bottom sheet used on map screens.
///
/// [child] is the sheet's body and scrolls whenever it doesn't fit — a small
/// phone, larger text, a long address. [footer] (the screen's primary actions)
/// sits below the body and never scrolls, so it is always on screen; put the
/// buttons that complete the screen's job there:
///
/// ```dart
/// McSheet(
///   footer: McButton('Start trip', onTap: _start),
///   child: Column(mainAxisSize: MainAxisSize.min, children: [...details]),
/// )
/// ```
///
/// The body is always inside a `SingleChildScrollView`, so it must not contain
/// a vertical `Expanded`/`Spacer` or an unbounded `ListView` (they would have
/// unbounded height to fill).
///
/// The sheet sizes to its content up to [maxHeight] — or, when that is null,
/// ~85% of the space it is given, so the top of the map and its floating
/// controls stay uncovered. Its paper runs under the system nav bar while its
/// content stays 12dp clear of it (28dp when there is no inset, as before).
/// A sheet whose parent already bounds its height (the one inside
/// `LiveRouteMap`) passes `maxHeight: double.infinity` so the 85% share is not
/// taken off the space it was already given.
class McSheet extends StatelessWidget {
  const McSheet({super.key, required this.child, this.footer, this.maxHeight});

  final Widget child;
  final Widget? footer;
  final double? maxHeight;

  /// Share of the available height a sheet may take when no [maxHeight] is set.
  static const double defaultHeightFactor = 0.85;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final cap = math.min(
              maxHeight ?? available * defaultHeightFactor, available);
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: cap),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 12, 20, _bottomPadding(context)),
              decoration: const BoxDecoration(
                color: Brand.paper,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: Brand.sheetShadow,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SheetHandle(),
                Flexible(child: SingleChildScrollView(child: child)),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ]),
            ),
          );
        },
      );
}

/// Pinned footer for a full-screen page's primary action — one button, or two
/// that belong together (Save / Cancel), stacked.
///
/// Put it in the Scaffold **body**, under an `Expanded` scrolling content area,
/// not in `bottomNavigationBar` — only the body is lifted above the keyboard:
///
/// ```dart
/// Scaffold(
///   backgroundColor: Brand.bg,
///   body: SafeArea(
///     bottom: false, // the bar handles the bottom inset itself
///     child: Column(children: [
///       header,
///       Expanded(child: SingleChildScrollView(child: form)),
///       McActionBar(children: [
///         McButton('Save', onTap: _save),
///         McGhostButton('Cancel', onTap: _cancel),
///       ]),
///     ]),
///   ),
/// )
/// ```
///
/// It adds the bottom system inset to its own padding, so its background runs
/// under the nav bar while the buttons stay clear of it. Under a SafeArea that
/// already consumed the inset it reads 0 there, so nothing is counted twice.
/// [color] should match the page background (most pages are [Brand.bg]).
class McActionBar extends StatelessWidget {
  const McActionBar({
    super.key,
    required this.children,
    this.color = Brand.bg,
    this.notice,
  });

  final List<Widget> children;
  final Color color;

  /// A message for the buttons below it — a failed submit's error. It sits
  /// inside the bar, so it is on screen whenever the button is: an error left
  /// at the end of the scroll body lands below the visible area (or under the
  /// keyboard) when the pinned button is the thing the driver just tapped.
  /// It is capped (about three lines, at most a quarter of the visible height)
  /// and scrolls inside itself when longer, so a long message never pushes the
  /// button off screen and is never truncated.
  final Widget? notice;

  /// The notice may take about three lines (banner padding included) at the
  /// current text size, but never more than a quarter of what is left of the
  /// screen — with the keyboard up that is the part above it, which the page
  /// body's MediaQuery no longer reports, so read it from the view.
  double _noticeMaxHeight(BuildContext context) {
    final view = View.of(context);
    final visible =
        (view.physicalSize.height - view.viewInsets.bottom) / view.devicePixelRatio;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return math.min(visible * 0.25, 3 * 14 * 1.4 * scale + 24);
  }

  @override
  Widget build(BuildContext context) {
    // Checked here rather than in the const constructor, where reading a list's
    // length would break `const McActionBar(children: [...])`.
    assert(children.isNotEmpty && children.length <= 2,
        'A pinned footer holds one or two buttons — more belongs in the page.');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          22, 12, 22, 12 + MediaQuery.paddingOf(context).bottom),
      // The tab bar's and the menu drawer footer's hairline: marks where the
      // scrolling content ends without a new colour or shadow.
      decoration: BoxDecoration(
        color: color,
        border: const Border(top: BorderSide(color: Brand.fill)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) ...[
            // Capped, and scrolling inside itself: a long message (the offline
            // one carries a "Ref:" line for support) must stay readable, but
            // must not grow the bar until it pushes the button off a small
            // screen. Never ellipsized - the cap is what scrolls.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: _noticeMaxHeight(context)),
              child: SingleChildScrollView(child: notice!),
            ),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: Brand.line, borderRadius: BorderRadius.circular(99)),
      );
}

/// Opens a modal bottom sheet the driver can always finish: the one way to
/// show a pop-up sheet in this app — use it instead of `showModalBottomSheet`.
///
/// What it adds over the bare call, each of which a sheet here got wrong:
///  • the content scrolls, and the sheet may grow past Flutter's default
///    9/16-of-the-screen cap (`isScrollControlled`) — the six-entry Language
///    list used to overflow that cap on a small phone;
///  • it stays below the status bar (`useSafeArea`) and its bottom padding
///    clears the nav bar / home indicator, so the last option isn't under it;
///  • it rides above the soft keyboard, measured from the sheet's own context.
///
/// [builder] returns the sheet's content only (include `SheetHandle()` as
/// before); this supplies the paper, the rounded top and the padding.
///
/// [floating] is for a sheet that draws its own card floating above the
/// bottom edge (the "Navigate with" picker): the route is transparent and only
/// the system inset is added below the card — the card keeps its own margin.
Future<T?> showMcBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool floating = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: floating ? Colors.transparent : Brand.paper,
    shape: floating
        ? null
        : const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
    builder: (sheetContext) {
      // `useSafeArea` handles the top and sides only; the bottom inset is left
      // in the sheet's MediaQuery for us to pad, so the paper still runs under
      // the nav bar. Read from the sheet's own context: the page's MediaQuery
      // may have had the keyboard taken out of it by its Scaffold.
      final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
      final bottom = floating
          ? MediaQuery.paddingOf(sheetContext).bottom
          : _bottomPadding(sheetContext);
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SingleChildScrollView(
          padding: floating
              ? EdgeInsets.only(bottom: bottom)
              : EdgeInsets.fromLTRB(20, 16, 20, bottom),
          child: builder(sheetContext),
        ),
      );
    },
  );
}

/// Bottom sheet offering "take a selfie" vs "choose from gallery" — the shared
/// entry point for any photo upload (profile picture, vehicle photos, docs).
/// Returns null if the driver dismisses it without picking either.
Future<ImageSource?> showPictureSourcePicker(BuildContext context) {
  return showMcBottomSheet<ImageSource>(
    context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHandle(),
        const McTitle('Add a photo', size: 20),
        const SizedBox(height: 6),
        Text('Take a selfie or choose one from your gallery',
            style: tw(FontWeight.w600, 13.5, Brand.sub)),
        const SizedBox(height: 16),
        _PictureSourceTile(
          icon: 'camera',
          title: 'Take a selfie',
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        const SizedBox(height: 10),
        _PictureSourceTile(
          icon: 'gallery',
          title: 'Choose from gallery',
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ],
    ),
  );
}

class _PictureSourceTile extends StatelessWidget {
  const _PictureSourceTile({required this.icon, required this.title, required this.onTap});
  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Brand.fill.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Brand.line),
          ),
          child: Row(
            children: [
              Ico(icon, size: 20, color: Brand.sub),
              const SizedBox(width: 12),
              Text(title, style: tw(FontWeight.w800, 14.5, Brand.ink)),
            ],
          ),
        ),
      );
}

/// Working N-box OTP / PIN input backed by a single hidden TextField.
///
/// Digits only, numeric keyboard, and the one-time-code autofill hint, so the
/// OS can offer a code it just received. [onChanged] reports every edit (for a
/// Confirm button that needs the partial value); [onCompleted] fires once the
/// last box is filled.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.boxHeight = 56,
    this.onCompleted,
    this.onChanged,
    this.autofocus = false,
    this.initialCode,
  });
  final int length;
  final double boxHeight;
  final ValueChanged<String>? onCompleted;

  /// Every edit, including deletions — for a screen whose Confirm button reads
  /// the current code rather than waiting for [onCompleted].
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// Pre-fills the boxes, e.g. with a code read from the SMS on Android.
  final String? initialCode;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final TextEditingController _c = TextEditingController();
  final FocusNode _f = FocusNode();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode;
    if (initial != null) _c.text = initial;
    _f.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _c.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _f.requestFocus(),
      child: Stack(
        children: [
          // Hidden input that actually captures keystrokes.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: widget.boxHeight,
              child: TextField(
                controller: _c,
                focusNode: _f,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: widget.length,
                onChanged: (v) {
                  setState(() {});
                  widget.onChanged?.call(v);
                  if (v.length == widget.length) widget.onCompleted?.call(v);
                },
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              ),
            ),
          ),
          Row(
            children: List.generate(widget.length, (i) {
              final filled = i < text.length;
              final focused = _f.hasFocus && i == text.length;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < widget.length - 1 ? 9 : 0),
                  child: Container(
                    height: widget.boxHeight,
                    decoration: BoxDecoration(
                      color: Brand.paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: focused ? Brand.blue : Brand.line, width: 1.5),
                      boxShadow: focused
                          ? [BoxShadow(color: Brand.blue.withValues(alpha: 0.13), blurRadius: 0, spreadRadius: 3)]
                          : null,
                    ),
                    child: Center(
                      child: filled
                          ? Text(text[i], style: tw(FontWeight.w900, 24, Brand.ink))
                          : (focused
                              ? Container(width: 2, height: 24, color: Brand.blue)
                              : const SizedBox.shrink()),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Round white floating control (back / menu / avatar buttons over a map).
/// A round, icon-only button.
///
/// Icon-only controls carry no text for a screen reader to fall back on, so
/// this one resolves a label: [semanticLabel] if given, else [_iconLabels] for
/// the icon name. An unmapped icon announces nothing rather than reading the
/// raw key ("chevR") aloud — add it to the map instead of passing it through.
class McCircleButton extends StatelessWidget {
  const McCircleButton(this.icon, {super.key, this.color = Brand.ink, this.onTap, this.semanticLabel});
  final String icon;
  final Color color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Labels for the icons this button is actually used with. Keep in sync with
  /// the driver app's copy.
  static const _iconLabels = <String, String>{
    'menu': 'Menu',
    'back': 'Back',
    'home': 'Home',
    'user': 'Account',
    'search': 'Search',
    'x': 'Close',
  };

  @override
  Widget build(BuildContext context) => mcTapSemantics(
        label: semanticLabel ?? _iconLabels[icon],
        enabled: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Brand.paper, shape: BoxShape.circle, boxShadow: Brand.floatShadow),
            child: Center(child: Ico(icon, size: 22, color: color)),
          ),
        ),
      );
}

/// Opens the slide-out menu drawer. Every screen gets one so the menu is
/// reachable without first navigating back to Home.
class McMenuButton extends ConsumerWidget {
  const McMenuButton({super.key, this.color = Brand.ink});
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      McCircleButton('menu', color: color, onTap: () => openMenuDrawer(ref));
}

/// Navigation header containing Back, Home and Menu buttons.
///
/// [showMenu] defaults on. Turn it off for the pre-login onboarding funnel:
/// the drawer's destinations and Log out assume a signed-in user, and on the
/// mid-signup screens (profile setup, registration, documents) a session token
/// already exists — so a menu there is a live escape hatch straight past
/// onboarding into the app.
class McNavHeader extends StatelessWidget {
  const McNavHeader({
    super.key,
    this.title,
    this.fallback = '/home',
    this.onBack,
    this.showHome = true,
    this.showBack = true,
    this.showMenu = true,
    this.trailing,
  });

  final String? title;
  final String fallback;
  final VoidCallback? onBack;
  final bool showHome;
  final bool showBack;
  final bool showMenu;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          McCircleButton('back', onTap: onBack ?? () => backOr(context, fallback))
        else
          const SizedBox(width: 44),
        if (title != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: McTitle(
              title!,
              size: 20,
              align: TextAlign.left,
            ),
          ),
        ] else
          const Spacer(),
        if (showHome) ...[
          const SizedBox(width: 8),
          McCircleButton('home', onTap: () => context.go('/home')),
        ],
        if (showMenu) ...[
          const SizedBox(width: 8),
          const McMenuButton(),
        ],
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

/// Floating counterpart to [McNavHeader], for the full-screen map screens that
/// have no in-flow header: Back pinned left, Home + Menu grouped right.
///
/// Drop it in a `Positioned(top: …, left: 16, right: 16)`.
class McFloatingNav extends StatelessWidget {
  const McFloatingNav({
    super.key,
    this.fallback = '/home',
    this.onBack,
    this.showBack = true,
    this.showHome = true,
    this.showMenu = true,
  });

  final String fallback;
  final VoidCallback? onBack;
  final bool showBack;
  final bool showHome;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showBack)
          McCircleButton('back', onTap: onBack ?? () => backOr(context, fallback))
        else
          const SizedBox(width: 44),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHome) McCircleButton('home', onTap: () => context.go('/home')),
            if (showHome && showMenu) const SizedBox(width: 8),
            if (showMenu) const McMenuButton(),
          ],
        ),
      ],
    );
  }
}

/// "Continue with Google" — white pill, per Google's sign-in branding.
///
/// The mark is drawn by [_GoogleGPainter] so no image asset is needed; swap it
/// for Google's official artwork before a public release.
class McGoogleButton extends StatelessWidget {
  const McGoogleButton({
    super.key,
    this.label = 'Continue with Google',
    this.onTap,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return mcTapSemantics(
      label: label,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: Brand.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Brand.line, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Brand.sub),
                  )
                else
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(painter: _GoogleGPainter()),
                  ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    loading ? 'Signing in…' : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tw(FontWeight.w800, 15.5, Brand.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Sign in with Apple" — Apple's own button widget, so the logo, typeface and
/// proportions stay within Apple's Human Interface Guidelines (App Review
/// checks). Only the height and corner radius are ours, to sit level with
/// [McGoogleButton]. Black on the light app background, as the HIG asks.
///
/// Callers show it on iOS only (`AppleSignInService.isAvailable`). While busy
/// it dims and ignores taps rather than swapping its title: the HIG allows only
/// Apple's three titles, so there is no "Signing in…" state to show.
class McAppleButton extends StatelessWidget {
  const McAppleButton({
    super.key,
    this.signUp = false,
    this.onTap,
    this.loading = false,
    this.height = 54,
  });

  final bool signUp;
  final VoidCallback? onTap;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final label = signUp ? 'Sign up with Apple' : 'Sign in with Apple';
    return mcTapSemantics(
      label: label,
      enabled: enabled,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: SignInWithAppleButton(
            text: label,
            height: height,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            onPressed: onTap ?? () {},
          ),
        ),
      ),
    );
  }
}

/// The four-colour Google "G": one ring split into four arcs, plus the blue bar.
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  static const _deg = 3.1415926535897932 / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.24;
    final rect = Rect.fromCircle(
      center: Offset(s / 2, s / 2),
      radius: (s - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    void arc(Color c, double startDeg, double sweepDeg) => canvas.drawArc(
        rect, startDeg * _deg, sweepDeg * _deg, false, paint..color = c);

    // Clockwise from 3 o'clock; the four sweeps add up to a full ring.
    arc(_blue, -30, 55);
    arc(_green, 25, 105);
    arc(_yellow, 130, 85);
    arc(_red, 215, 115);

    // The bar joining the centre to the blue arc.
    canvas.drawRect(
      Rect.fromLTRB(s * 0.5, s / 2 - stroke / 2, s - stroke, s / 2 + stroke / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter oldDelegate) => false;
}

/// Hairline rule with a centred caption — separates a screen's primary action
/// from an alternative one (e.g. "New to Mapcars?" above the Sign up button).
class McDividerLabel extends StatelessWidget {
  const McDividerLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Brand.line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: tw(FontWeight.w700, 13, Brand.sub)),
        ),
        const Expanded(child: Divider(color: Brand.line, height: 1)),
      ],
    );
  }
}

/// Red alert banner for validation / auth error messages.
class McErrorBanner extends StatelessWidget {
  const McErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Brand.errorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Brand.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 20, color: Brand.errorText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: tw(FontWeight.w700, 13.5, Brand.errorText),
            ),
          ),
        ],
      ),
    );
  }
}
