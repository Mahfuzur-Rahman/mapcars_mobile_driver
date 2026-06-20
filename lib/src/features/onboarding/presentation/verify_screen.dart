import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _phone = TextEditingController(text: '7700 900812');

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final digits =
        _phone.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (digits.isEmpty) return;
    await ref.read(authNotifierProvider.notifier).sendPhoneOtp('+44$digits');
  }

  Future<void> _verify(String code) async {
    final ok = await ref.read(authNotifierProvider.notifier).verifyPhoneOtp(code);
    if (!ok || !mounted) return;
    // New drivers continue onboarding; returning, completed drivers go straight in.
    final profileComplete = ref.read(authNotifierProvider).isProfileComplete;
    context.go(profileComplete ? '/home' : '/registration');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final codeSent = auth.pendingPhone != null;

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              McCircleButton('back', onTap: () => context.pop()),
              const SizedBox(height: 20),
              const McTitle('Verify your phone', size: 25),
              const SizedBox(height: 8),
              Text("We'll text a 6-digit code to confirm it's you.",
                  style: tw(FontWeight.w600, 15, Brand.sub)),
              const SizedBox(height: 22),
              Row(
                children: [
                  const McField(value: '🇬🇧 +44', width: 104),
                  const SizedBox(width: 10),
                  Expanded(
                    child: McField(
                      controller: _phone,
                      editable: true,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              if (codeSent) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Brand.line, height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('ENTER CODE',
                          style: tw(FontWeight.w800, 12, Brand.faint)),
                    ),
                    const Expanded(child: Divider(color: Brand.line, height: 1)),
                  ],
                ),
                const SizedBox(height: 18),
                OtpInput(length: 6, boxHeight: 56, onCompleted: _verify),
                const SizedBox(height: 16),
                // In dev the API echoes the code so you can type it without SMS.
                if (AppConfig.showDevOtp && auth.devOtpCode != null)
                  Text('Dev code: ${auth.devOtpCode}',
                      style: tw(FontWeight.w800, 13.5, Brand.blue)),
                GestureDetector(
                  onTap: auth.isLoading ? null : _sendCode,
                  child: Text('Resend code',
                      style: tw(FontWeight.w700, 13.5, Brand.sub)),
                ),
              ],
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!, style: tw(FontWeight.w600, 13, Colors.red)),
              ],
              const Spacer(),
              McButton(
                auth.isLoading
                    ? 'Please wait…'
                    : (codeSent ? 'Resend code' : 'Send code'),
                icon: auth.isLoading ? null : 'check',
                onTap: auth.isLoading ? null : _sendCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
