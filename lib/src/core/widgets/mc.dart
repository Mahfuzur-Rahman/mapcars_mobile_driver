import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/mc_icons.dart';

export '../theme/brand.dart';
export '../theme/mc_icons.dart';

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
          boxShadow: [BoxShadow(color: Brand.blue.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
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
