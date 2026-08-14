import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../auth/services/driver_auth_service.dart';

/// Shared "your details" form used by both the onboarding Registration step
/// and the post-login Profile edit screen — full name, DOB, address,
/// national ID, and a profile picture.
class DriverProfileForm extends ConsumerStatefulWidget {
  const DriverProfileForm({
    super.key,
    required this.submitLabel,
    required this.onSubmitted,
  });

  final String submitLabel;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<DriverProfileForm> createState() => _DriverProfileFormState();
}

class _DriverProfileFormState extends ConsumerState<DriverProfileForm> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _drivingLicenceCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  DateTime? _dob;
  bool _hasPicture = false;
  bool _marketingConsent = false;
  bool _loading = true;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(authNotifierProvider.notifier).loadProfile();
    if (!mounted) return;
    if (profile != null) {
      _nameCtrl.text = [profile.firstName, profile.lastName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      _addressCtrl.text = profile.address ?? '';
      _nationalIdCtrl.text = profile.nationalIdNumber ?? '';
      _drivingLicenceCtrl.text = profile.drivingLicenceNumber ?? '';
      _passportCtrl.text = profile.passportNumber ?? '';
      _emergencyNameCtrl.text = profile.emergencyContactName ?? '';
      _emergencyPhoneCtrl.text = profile.emergencyContactPhone ?? '';
      _dob = profile.dateOfBirth;
      _hasPicture = profile.hasProfilePicture;
      _marketingConsent = profile.marketingConsent;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _nationalIdCtrl.dispose();
    _drivingLicenceCtrl.dispose();
    _passportCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPicture() async {
    final source = await showPictureSourcePicker(context);
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .uploadProfilePicture(File(picked.path));
    if (ok && mounted) setState(() => _hasPicture = true);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    final fullName = _nameCtrl.text.trim();
    final nationalId = _nationalIdCtrl.text.trim();
    if (fullName.isEmpty) {
      setState(() => _formError = 'Please enter your full legal name.');
      return;
    }
    if (nationalId.isEmpty) {
      setState(() => _formError = 'Please enter your National Insurance number.');
      return;
    }
    setState(() => _formError = null);

    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final ok = await ref.read(authNotifierProvider.notifier).updateProfile(
          firstName: firstName,
          lastName: lastName,
          dateOfBirth: _dob,
          address: _addressCtrl.text.trim(),
          nationalIdNumber: nationalId,
          drivingLicenceNumber: _drivingLicenceCtrl.text.trim(),
          passportNumber: _passportCtrl.text.trim(),
          emergencyContactName: _emergencyNameCtrl.text.trim(),
          emergencyContactPhone: _emergencyPhoneCtrl.text.trim(),
          marketingConsent: _marketingConsent,
        );
    if (ok) widget.onSubmitted();
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final token = ref.watch(authTokenProvider);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickPicture,
            child: SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _hasPicture && token != null
                      ? ClipOval(
                          child: Image.network(
                            ref.read(driverAuthServiceProvider).profilePictureUrl(Env.apiBaseUrl),
                            headers: {'Authorization': 'Bearer $token'},
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => const McAvatar(size: 84),
                          ),
                        )
                      : const McAvatar(size: 84),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Brand.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Center(child: Ico('camera', size: 14, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _label('Full legal name', required: true),
        McField(icon: 'user', controller: _nameCtrl, editable: true),
        const SizedBox(height: 12),
        _label('Date of birth'),
        McField(
          icon: 'cal',
          value: _dob == null ? null : _formatDob(_dob!),
          placeholder: 'DD / MM / YYYY',
          onTap: _pickDob,
        ),
        const SizedBox(height: 12),
        _label('Home address'),
        McField(icon: 'pin', controller: _addressCtrl, editable: true),
        const SizedBox(height: 12),
        _label('National Insurance no.', required: true),
        McField(icon: 'doc', controller: _nationalIdCtrl, editable: true),
        const SizedBox(height: 12),
        _label('DVLA driving licence no.'),
        McField(icon: 'card', controller: _drivingLicenceCtrl, editable: true),
        const SizedBox(height: 12),
        _label('Passport number (or description)'),
        McField(icon: 'doc', controller: _passportCtrl, editable: true),
        const SizedBox(height: 12),
        _label('Emergency contact name'),
        McField(icon: 'user', controller: _emergencyNameCtrl, editable: true),
        const SizedBox(height: 12),
        _label('Emergency contact phone'),
        McField(
          icon: 'phone',
          controller: _emergencyPhoneCtrl,
          editable: true,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        McCard(
          padding: 14,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Send me news, offers and product updates',
                  style: tw(FontWeight.w700, 13.5, Brand.ink),
                ),
              ),
              Switch(
                value: _marketingConsent,
                activeThumbColor: Brand.blue,
                onChanged: (v) => setState(() => _marketingConsent = v),
              ),
            ],
          ),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 12),
          Text(_formError!, style: tw(FontWeight.w600, 13, Colors.red)),
        ] else if (auth.error != null) ...[
          const SizedBox(height: 12),
          Text(auth.error!, style: tw(FontWeight.w600, 13, Colors.red)),
        ],
        const SizedBox(height: 20),
        McButton(
          auth.isLoading ? 'Saving…' : widget.submitLabel,
          icon: auth.isLoading ? null : 'chevR',
          onTap: auth.isLoading ? null : _submit,
        ),
      ],
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: RichText(
          text: TextSpan(
            style: tw(FontWeight.w800, 12, Brand.sub),
            children: [
              TextSpan(text: text),
              if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
}
