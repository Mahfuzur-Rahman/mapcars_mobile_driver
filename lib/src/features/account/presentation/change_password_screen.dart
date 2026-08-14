import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Mirrors the StrongPassword rule on the API — fail fast, client-side.
  bool _isStrong(String p) =>
      p.length >= 8 && RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p);

  Future<void> _submit() async {
    setState(() => _localError = null);
    ref.read(authNotifierProvider.notifier).clearError();

    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    if (current.isEmpty) {
      setState(() => _localError = 'Enter your current password.');
      return;
    }
    if (!_isStrong(next)) {
      setState(() => _localError =
          'New password needs at least 8 characters, one uppercase letter, and one digit.');
      return;
    }
    if (next != _confirmCtrl.text) {
      setState(() => _localError = "New passwords don't match.");
      return;
    }

    final ok = await ref.read(authNotifierProvider.notifier).changePassword(
          currentPassword: current,
          newPassword: next,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final error = _localError ?? auth.error;

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Ico('chevL', size: 22, color: Brand.ink),
                  ),
                  const SizedBox(width: 12),
                  const McTitle('Change password', size: 22),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      McField(
                        icon: 'lock',
                        placeholder: 'Current password',
                        controller: _currentCtrl,
                        editable: true,
                        obscure: true,
                      ),
                      const SizedBox(height: 12),
                      McField(
                        icon: 'lock',
                        placeholder: 'New password',
                        controller: _newCtrl,
                        editable: true,
                        obscure: true,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'At least 8 characters, one uppercase letter, one digit.',
                        style: tw(FontWeight.w600, 12, Brand.sub),
                      ),
                      const SizedBox(height: 12),
                      McField(
                        icon: 'lock',
                        placeholder: 'Confirm new password',
                        controller: _confirmCtrl,
                        editable: true,
                        obscure: true,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error, style: tw(FontWeight.w600, 13, Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              McButton(
                auth.isLoading ? 'Saving…' : 'Change password',
                icon: auth.isLoading ? null : 'check',
                onTap: auth.isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
