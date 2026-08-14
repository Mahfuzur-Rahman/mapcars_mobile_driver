import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

enum SignupMethod { phone, email }

/// Single-page sign-up screen. The driver first picks *how* they want to sign
/// up (phone number or email), then fills in the fields for that choice.
class EmailSignupScreen extends ConsumerStatefulWidget {
  const EmailSignupScreen({super.key, this.initialMethod = SignupMethod.phone});

  final SignupMethod initialMethod;

  @override
  ConsumerState<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends ConsumerState<EmailSignupScreen> {
  late SignupMethod _method;

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  String? _localError;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPhone() async {
    final digits =
        _phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (digits.isEmpty) {
      setState(() => _localError = 'Please enter a valid phone number.');
      return;
    }
    setState(() => _localError = null);
    await ref.read(authNotifierProvider.notifier).sendPhoneOtp('+44$digits');
    if (mounted) context.go('/verify');
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _localError = null);
    final ok =
        await ref.read(authNotifierProvider.notifier).continueWithGoogle(signUp: true);
    if (!ok || !mounted) return;
    final complete = ref.read(authNotifierProvider).isProfileComplete;
    context.go(complete ? '/home' : '/registration');
  }

  Future<void> _submitEmail() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _localError = 'Please fill in every field.');
      return;
    }
    if (password.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters.');
      return;
    }
    setState(() => _localError = null);

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .signUpWithEmail(email, password, name);
    if (ok && mounted) context.go('/verify-email');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final error = _localError ?? auth.error;
    final isPhone = _method == SignupMethod.phone;

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McNavHeader(fallback: '/verify', showMenu: false),
              const SizedBox(height: 18),

              const McTitle('Sign up', size: 28),
              const SizedBox(height: 8),
              Text(
                'How would you like to create your driver account?',
                style: tw(FontWeight.w600, 15, Brand.sub),
              ),
              const SizedBox(height: 18),

              // Explicit choice of sign-up method — one card per option, so it
              // is obvious both exist and which one is currently selected.
              _SignupOption(
                icon: 'phone',
                title: 'With my phone number',
                subtitle: "We'll text you a 6-digit code — no password needed.",
                selected: isPhone,
                onTap: () => setState(() {
                  _method = SignupMethod.phone;
                  _localError = null;
                }),
              ),
              const SizedBox(height: 10),
              _SignupOption(
                icon: 'mail',
                title: 'With my email address',
                subtitle: 'Create an account with an email and password.',
                selected: !isPhone,
                onTap: () => setState(() {
                  _method = SignupMethod.email;
                  _localError = null;
                }),
              ),

              const SizedBox(height: 22),
              Text(
                isPhone ? 'Your phone number' : 'Your details',
                style: tw(FontWeight.w800, 13, Brand.faint, 0.4),
              ),
              const SizedBox(height: 10),

              if (isPhone) ...[
                Row(
                  children: [
                    const McField(value: '🇬🇧 +44', width: 104),
                    const SizedBox(width: 10),
                    Expanded(
                      child: McField(
                        controller: _phoneCtrl,
                        editable: true,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        placeholder: '7700 900000',
                      ),
                    ),
                  ],
                ),
              ] else ...[
                McField(
                  icon: 'user',
                  placeholder: 'Full name',
                  controller: _nameCtrl,
                  editable: true,
                  autofocus: true,
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 12),
                McField(
                  icon: 'mail',
                  placeholder: 'Email address',
                  controller: _emailCtrl,
                  editable: true,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                McField(
                  icon: 'lock',
                  placeholder: 'Password (min 8 characters)',
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
                    ? (isPhone ? 'Sending code…' : 'Creating account…')
                    : (isPhone ? 'Continue' : 'Create account'),
                icon: auth.isLoading ? null : 'chevR',
                onTap: auth.isLoading
                    ? null
                    : (isPhone ? _submitPhone : _submitEmail),
              ),

              const SizedBox(height: 18),
              const McDividerLabel('or'),
              const SizedBox(height: 14),
              McGoogleButton(
                label: 'Sign up with Google',
                loading: auth.isLoading,
                onTap: auth.isLoading ? null : _continueWithGoogle,
              ),

              const SizedBox(height: 20),
              const McDividerLabel('Already have an account?'),
              const SizedBox(height: 14),
              McButton(
                'Sign in',
                icon: 'lock',
                kind: BtnKind.green,
                onTap: () => context.go('/verify'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width, tappable sign-up option (phone / email) showing an icon, a
/// plain-English label, what it means, and a radio dot for the selected one.
class _SignupOption extends StatelessWidget {
  const _SignupOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Brand.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Brand.blue : Brand.line,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? Brand.cardShadow : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Brand.blue.withValues(alpha: 0.10)
                      : Brand.fill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Ico(icon,
                    size: 20, color: selected ? Brand.blue : Brand.sub),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tw(FontWeight.w800, 15.5, Brand.ink)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: tw(FontWeight.w600, 12.5, Brand.sub)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Brand.blue : Colors.transparent,
        border: Border.all(
          color: selected ? Brand.blue : Brand.line,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 13, color: Brand.paper)
          : null,
    );
  }
}
