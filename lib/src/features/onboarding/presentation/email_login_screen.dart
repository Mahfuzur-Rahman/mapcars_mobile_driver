import 'package:flutter/material.dart';

import 'verify_screen.dart';

/// Email + password login for drivers (delegates to unified single-page VerifyScreen with email tab selected).
class EmailLoginScreen extends StatelessWidget {
  const EmailLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VerifyScreen(initialTab: AuthTab.email);
  }
}
