import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/mc.dart';

/// "Resend code in 0:42" until [availableAt], then a tappable "Resend code".
/// The time comes from the server (resendAfterSeconds, or retryAfterSeconds on a
/// 429), so the countdown can't promise a resend the API would refuse.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.availableAt,
    required this.onResend,
    this.busy = false,
  });

  final DateTime? availableAt;
  final VoidCallback onResend;
  final bool busy;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.availableAt;
    final left = at == null ? Duration.zero : at.difference(DateTime.now());

    if (left > Duration.zero) {
      final s = left.inSeconds + 1;
      final mmss = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
      return Row(
        children: [
          const Ico('clock', size: 16, color: Brand.faint),
          const SizedBox(width: 6),
          Text('Resend code in $mmss', style: tw(FontWeight.w700, 14, Brand.sub)),
        ],
      );
    }

    return GestureDetector(
      onTap: widget.busy ? null : widget.onResend,
      child: Row(
        children: [
          const Ico('clock', size: 16, color: Brand.blue),
          const SizedBox(width: 6),
          Text('Resend code', style: tw(FontWeight.w800, 14, Brand.blue)),
        ],
      ),
    );
  }
}
