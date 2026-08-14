import 'package:flutter/material.dart';

import '../../../core/widgets/mc.dart';
import 'driver_profile_form.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  const McTitle('Edit profile', size: 22),
                  const Spacer(),
                  const McMenuButton(),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: DriverProfileForm(
                    submitLabel: 'Save changes',
                    onSubmitted: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
