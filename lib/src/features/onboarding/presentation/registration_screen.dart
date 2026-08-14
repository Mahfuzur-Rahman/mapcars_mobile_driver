import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../account/presentation/driver_profile_form.dart';

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const McNavHeader(title: 'Your details', fallback: '/verify', showMenu: false),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(3, (i) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: i == 0 ? Brand.blue : Brand.line,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text('Step 1 of 3 · Personal info', style: tw(FontWeight.w600, 13, Brand.sub)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                child: DriverProfileForm(
                  submitLabel: 'Continue',
                  onSubmitted: () => context.go('/documents'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
