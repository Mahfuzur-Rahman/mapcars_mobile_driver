import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

enum AuthTab { phone, email }

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, this.initialTab = AuthTab.phone});

  final AuthTab initialTab;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  late AuthTab _activeTab;
  final _phoneCtrl = TextEditingController();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final digits =
        _phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (digits.isEmpty) {
      setState(() => _localError = 'Please enter a valid phone number.');
      return;
    }
    setState(() => _localError = null);
    await ref.read(authNotifierProvider.notifier).sendPhoneOtp('+44$digits');
  }

  Future<void> _verifyOtp(String code) async {
    final ok =
        await ref.read(authNotifierProvider.notifier).verifyPhoneOtp(code);
    if (!ok || !mounted) return;
    final profileComplete = ref.read(authNotifierProvider).isProfileComplete;
    context.go(profileComplete ? '/home' : '/registration');
  }

  Future<void> _continueWithGoogle() async {
    final ok =
        await ref.read(authNotifierProvider.notifier).continueWithGoogle(signUp: true);
    if (!ok || !mounted) return;
    final complete = ref.read(authNotifierProvider).isProfileComplete;
    context.go(complete ? '/home' : '/registration');
  }

  Future<void> _submitEmailLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _localError = 'Please enter your email and password.');
      return;
    }
    setState(() => _localError = null);

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .loginWithEmail(email, password);

    if (!ok || !mounted) return;
    final profileComplete = ref.read(authNotifierProvider).isProfileComplete;
    context.go(profileComplete ? '/home' : '/registration');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final error = _localError ?? auth.error;
    final codeSent = auth.pendingPhone != null;
    final isPhone = _activeTab == AuthTab.phone;

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McNavHeader(fallback: '/intro', showMenu: false),
              const SizedBox(height: 18),

              // Segmented tab switch for Phone / Email
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Brand.line.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Phone number',
                        icon: 'phone',
                        active: isPhone,
                        onTap: () => setState(() {
                          _activeTab = AuthTab.phone;
                          _localError = null;
                        }),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'Email & password',
                        icon: 'mail',
                        active: !isPhone,
                        onTap: () => setState(() {
                          _activeTab = AuthTab.email;
                          _localError = null;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              if (isPhone) ...[
                const McTitle('Log in with phone', size: 25),
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
                        controller: _phoneCtrl,
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
                      const Expanded(
                          child: Divider(color: Brand.line, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('ENTER CODE',
                            style: tw(FontWeight.w800, 12, Brand.faint)),
                      ),
                      const Expanded(
                          child: Divider(color: Brand.line, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OtpInput(length: 6, boxHeight: 56, onCompleted: _verifyOtp),
                  const SizedBox(height: 16),
                  if (AppConfig.showDevOtp && auth.devOtpCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCF3D5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEECB5F)),
                      ),
                      child: Row(
                        children: [
                          const Ico('phone',
                              size: 16, color: Color(0xFFB07310)),
                          const SizedBox(width: 8),
                          Text(
                            'Dev OTP: ${auth.devOtpCode}',
                            style: tw(FontWeight.w700, 14,
                                const Color(0xFFB07310)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  GestureDetector(
                    onTap: auth.isLoading ? null : _sendCode,
                    child: Text('Resend code',
                        style: tw(FontWeight.w700, 13.5, Brand.sub)),
                  ),
                ],
              ] else ...[
                const McTitle('Log in with email', size: 25),
                const SizedBox(height: 8),
                Text('Welcome back! Enter your email and password.',
                    style: tw(FontWeight.w600, 15, Brand.sub)),
                const SizedBox(height: 22),
                McField(
                  icon: 'mail',
                  placeholder: 'Email address',
                  controller: _emailCtrl,
                  editable: true,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                McField(
                  icon: 'lock',
                  placeholder: 'Password',
                  controller: _passwordCtrl,
                  editable: true,
                  obscure: _obscurePassword,
                  suffix: GestureDetector(
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: Brand.sub,
                    ),
                  ),
                ),
              ],

              if (error != null) ...[
                const SizedBox(height: 14),
                McErrorBanner(error),
              ],

              const SizedBox(height: 24),
              McButton(
                auth.isLoading
                    ? 'Please wait…'
                    : (isPhone
                        ? (codeSent ? 'Resend code' : 'Send code')
                        : 'Sign in'),
                icon: auth.isLoading ? null : 'check',
                onTap: auth.isLoading
                    ? null
                    : (isPhone ? _sendCode : _submitEmailLogin),
              ),
              const SizedBox(height: 18),
              const McDividerLabel('or'),
              const SizedBox(height: 14),
              McGoogleButton(
                loading: auth.isLoading,
                onTap: auth.isLoading ? null : _continueWithGoogle,
              ),

              const SizedBox(height: 20),
              const McDividerLabel("Don't have an account?"),
              const SizedBox(height: 14),
              McButton(
                'Sign up',
                icon: 'user',
                kind: BtnKind.green,
                onTap: () => context.go('/email-signup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Brand.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x1A16202E),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Ico(icon, size: 16, color: active ? Brand.blue : Brand.sub),
            const SizedBox(width: 8),
            Text(
              label,
              style: tw(
                active ? FontWeight.w800 : FontWeight.w600,
                13.5,
                active ? Brand.ink : Brand.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
