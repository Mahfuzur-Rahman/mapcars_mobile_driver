import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/friendly_error.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/services/driver_auth_service.dart';

/// Error text for the profile-email endpoints. A 429 carries no body, so the
/// generic "Too many attempts" would be all the driver sees — say what to do.
String profileEmailError(Object e) {
  if (e is ApiException && e.statusCode == 429) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }
  return friendlyError(e);
}

/// Code-entry sheet for verifying the email on a signed-in driver's profile.
///
/// The caller has already sent the first code (`POST /me/email/send-code`) and
/// passes its result in [sent]. Resolves to the updated profile once the code
/// is accepted, or null if the driver closes the sheet first.
Future<DriverProfile?> showVerifyEmailSheet(
  BuildContext context, {
  required OtpSentResult sent,
}) =>
    showMcBottomSheet<DriverProfile>(
      context,
      builder: (_) => _VerifyEmailSheet(initial: sent),
    );

class _VerifyEmailSheet extends ConsumerStatefulWidget {
  const _VerifyEmailSheet({required this.initial});
  final OtpSentResult initial;

  @override
  ConsumerState<_VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends ConsumerState<_VerifyEmailSheet> {
  /// A fresh code is sent on every resend; the API also rate-limits these, so
  /// the button rests between sends rather than inviting a 429.
  static const _resendCooldown = 30;

  late String _message = widget.initial.message;
  late String? _devCode = widget.initial.devCode;
  String _code = '';
  String? _error;
  bool _verifying = false;
  bool _resending = false;
  int _cooldown = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  bool get _busy => _verifying || _resending;

  Future<void> _confirm() async {
    if (_busy || _code.length < 6) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final profile =
          await ref.read(driverAuthServiceProvider).verifyProfileEmail(_code);
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } catch (e) {
      // A wrong/expired code is a 400 with the API's own wording.
      if (mounted) setState(() => _error = profileEmailError(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _cooldown > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final sent = await ref.read(driverAuthServiceProvider).sendProfileEmailCode();
      if (!mounted) return;
      setState(() {
        _message = sent.message;
        _devCode = sent.devCode;
      });
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = profileEmailError(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _resendLabel {
    if (_resending) return 'Sending code…';
    if (_cooldown > 0) {
      return 'Resend code in 0:${_cooldown.toString().padLeft(2, '0')}';
    }
    return 'Resend code';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: SheetHandle()),
        const McTitle('Verify your email', size: 20),
        const SizedBox(height: 6),
        Text(
          '${_message.endsWith('.') ? _message : '$_message.'} '
          'Enter the 6-digit code below.',
          style: tw(FontWeight.w600, 13.5, Brand.sub),
        ),
        const SizedBox(height: 18),
        OtpInput(
          length: 6,
          boxHeight: 56,
          autofocus: true,
          onChanged: (v) => setState(() {
            _code = v;
            _error = null;
          }),
          onCompleted: (v) {
            _code = v;
            _confirm();
          },
        ),
        if (AppConfig.showDevOtp && _devCode != null) ...[
          const SizedBox(height: 12),
          Text('Dev code: $_devCode',
              style: tw(FontWeight.w700, 13, Brand.sub)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          McErrorBanner(_error!),
        ],
        const SizedBox(height: 18),
        McButton(
          _verifying ? 'Verifying…' : 'Confirm',
          icon: _verifying ? null : 'check',
          kind: BtnKind.green,
          onTap: (_busy || _code.length < 6) ? null : _confirm,
        ),
        const SizedBox(height: 10),
        McGhostButton(
          _resendLabel,
          icon: (_resending || _cooldown > 0) ? null : 'mail',
          onTap: (_busy || _cooldown > 0) ? null : _resend,
        ),
      ],
    );
  }
}
