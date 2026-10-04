import 'package:flutter/material.dart';

import '../../../core/widgets/mc.dart';
import 'driver_profile_form.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = DriverProfileFormController();

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        // "Save changes" is pinned in the save bar, which handles the bottom
        // inset itself (so no SafeArea there) and rides above the keyboard.
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Row(
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
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: DriverProfileForm(
                  controller: _form,
                  onSubmitted: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            DriverProfileSaveBar(controller: _form, label: 'Save changes'),
          ],
        ),
      ),
    );
  }
}
