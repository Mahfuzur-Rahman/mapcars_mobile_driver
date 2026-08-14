import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

/// Code-entry screen for driver email sign-up. The code expires after 3 minutes
/// (matches the API); a live countdown gates the "Resend code" action.
class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  static const _ttlSeconds = 180; // 3 minutes

  String _code = '';
  int _secondsLeft = _ttlSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _ttlSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _mmss {
    final m = _secondsLeft ~/ 60;
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify() async {
    final email = ref.read(authNotifierProvider).email;
    if (email == null || _code.length < 6) return;
    if (_secondsLeft == 0) return;
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .verifyEmailOtp(email, _code);
    if (!mounted || !ok) return;
    // New drivers continue onboarding; completed drivers go straight in.
    final auth = ref.read(authNotifierProvider);
    context.go(auth.isProfileComplete ? '/home' : '/registration');
  }

  Future<void> _resend() async {
    final email = ref.read(authNotifierProvider).email;
    if (email == null) return;
    final ok =
        await ref.read(authNotifierProvider.notifier).resendEmailOtp(email);
    if (ok && mounted) _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final email = auth.email ?? '';
    final expired = _secondsLeft == 0;

    return AppBackScope(
      fallback: '/email-signup',
      child: Scaffold(
        backgroundColor: Brand.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                McCircleButton('back',
                    onTap: () => backOr(context, '/email-signup')),
                const SizedBox(height: 22),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const McTitle('Verify your email', size: 25),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            text: 'We sent a 6-digit code to $email. ',
                            style: tw(FontWeight.w600, 15, Brand.sub),
                            children: [
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => backOr(context, '/email-signup'),
                                  child: Text('Edit',
                                      style: tw(FontWeight.w800, 15, Brand.green)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        OtpInput(
                          length: 6,
                          boxHeight: 60,
                          onCompleted: (code) {
                            setState(() => _code = code);
                            _verify();
                          },
                        ),
                        if (AppConfig.showDevOtp && auth.devOtpCode != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCF3D5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFEECB5F)),
                            ),
                            child: Row(
                              children: [
                                const Ico('mail', size: 16, color: Color(0xFFB07310)),
                                const SizedBox(width: 8),
                                Text(
                                  'Dev code: ${auth.devOtpCode}',
                                  style: tw(FontWeight.w700, 14, const Color(0xFFB07310)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (auth.error != null) ...[
                          const SizedBox(height: 12),
                          Text(auth.error!, style: tw(FontWeight.w600, 13, Colors.red)),
                        ],
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Ico('clock',
                                size: 16, color: expired ? Colors.red : Brand.faint),
                            const SizedBox(width: 6),
                            Text(
                              expired ? 'Code expired' : 'Code expires in $_mmss',
                              style: tw(FontWeight.w700, 14,
                                  expired ? Colors.red : Brand.sub),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: (expired && !auth.isLoading) ? _resend : null,
                              child: Text(
                                'Resend code',
                                style: tw(FontWeight.w800, 14,
                                    expired ? Brand.green : Brand.faint),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                McButton(
                  auth.isLoading ? 'Verifying…' : 'Verify',
                  icon: auth.isLoading ? null : 'check',
                  kind: BtnKind.green,
                  onTap: (auth.isLoading || expired) ? null : _verify,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
