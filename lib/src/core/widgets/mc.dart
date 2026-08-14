import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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

/// Primary (filled / gradient) button.
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
    return GestureDetector(
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
    );
  }
}

/// Secondary (outline) button.
class McGhostButton extends StatelessWidget {
  const McGhostButton(this.label, {super.key, this.icon, this.full = true, this.onTap, this.height = 54});
  final String label;
  final String? icon;
  final bool full;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) => GestureDetector(
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
  Widget build(BuildContext context) => GestureDetector(
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
      );
}

class McChip extends StatelessWidget {
  const McChip(this.label, {super.key, this.icon, this.active = false, this.onTap});
  final String label;
  final String? icon;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
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

/// Rounded bottom sheet used on map screens.
class McSheet extends StatelessWidget {
  const McSheet({super.key, required this.child, this.height});
  final Widget child;
  final double? height;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: Brand.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: Brand.sheetShadow,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          Flexible(child: child),
        ]),
      );
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

/// Bottom sheet offering "take a selfie" vs "choose from gallery" — the shared
/// entry point for any photo upload (profile picture, vehicle photos, docs).
/// Returns null if the driver dismisses it without picking either.
Future<ImageSource?> showPictureSourcePicker(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
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
class OtpInput extends StatefulWidget {
  const OtpInput({super.key, this.length = 6, this.boxHeight = 56, this.onCompleted});
  final int length;
  final double boxHeight;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final TextEditingController _c = TextEditingController();
  final FocusNode _f = FocusNode();

  @override
  void initState() {
    super.initState();
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
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                onChanged: (v) {
                  setState(() {});
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
class McCircleButton extends StatelessWidget {
  const McCircleButton(this.icon, {super.key, this.color = Brand.ink, this.onTap});
  final String icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Brand.paper, shape: BoxShape.circle, boxShadow: Brand.floatShadow),
          child: Center(child: Ico(icon, size: 22, color: color)),
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
    return Semantics(
      button: true,
      label: label,
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
