import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../auth/services/driver_auth_service.dart';
import 'verify_email_sheet.dart';

/// Handle between a [DriverProfileForm] and the screen that hosts it.
///
/// The form scrolls, but its save button must not: the hosting screen pins it
/// in a [DriverProfileSaveBar] under the scroll view, so it is always on screen
/// (above the keyboard, clear of the nav bar). The screen creates one of these,
/// hands it to the form and the bar, and disposes it:
///
/// ```dart
/// final _form = DriverProfileFormController();
/// ...
/// Column(children: [
///   Expanded(child: SingleChildScrollView(
///     child: DriverProfileForm(controller: _form, onSubmitted: ...))),
///   DriverProfileSaveBar(controller: _form, label: 'Save changes'),
/// ])
/// ```
///
/// Validation and the save itself still live in the form; this only lets the
/// bar start them and show the result.
class DriverProfileFormController extends ChangeNotifier {
  Future<void> Function()? _submit;
  bool _ready = false;
  String? _formError;

  /// True once the form has loaded the saved profile and can be submitted —
  /// saving before that would overwrite the profile with blanks.
  bool get ready => _ready;

  /// The form's own validation message ("Please enter your full legal name."),
  /// or null. An API error is shown from the auth state instead.
  String? get formError => _formError;

  /// Runs the form's validation and, if it passes, saves. No-op until [ready].
  Future<void> submit() async {
    if (!_ready) return;
    await _submit?.call();
  }

  void _attach(Future<void> Function() submit) => _submit = submit;

  /// The form is going away: forget it without notifying (the host is being
  /// torn down in the same frame).
  void _detach() {
    _submit = null;
    _ready = false;
  }

  void _setReady() {
    _ready = true;
    notifyListeners();
  }

  void _setFormError(String? message) {
    if (_formError == message) return;
    _formError = message;
    notifyListeners();
  }
}

/// The pinned "Save changes" / "Continue" bar for a [DriverProfileForm]: an
/// [McActionBar] with the form's error (if any) just above it, so a validation
/// message is never off-screen at the top of a scrolled form while the button
/// sits at the bottom.
class DriverProfileSaveBar extends ConsumerWidget {
  const DriverProfileSaveBar({
    super.key,
    required this.controller,
    required this.label,
  });

  final DriverProfileFormController controller;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final error = controller.formError ?? auth.error;
        final busy = auth.isLoading;
        // The error rides in the bar's capped, self-scrolling notice area, so a
        // long one (the offline message with its "Ref:" line) is never cut and
        // never pushes the button off a keyboard-covered screen.
        return McActionBar(
          notice: error == null
              ? null
              : Text(error, style: tw(FontWeight.w600, 13, Colors.red)),
          children: [
            McButton(
              busy ? 'Saving…' : label,
              icon: busy ? null : 'chevR',
              onTap: (busy || !controller.ready) ? null : controller.submit,
            ),
          ],
        );
      },
    );
  }
}

/// Shared "your details" form used by both the onboarding Registration step
/// and the post-login Profile edit screen — full name, DOB, address,
/// national ID, and a profile picture.
class DriverProfileForm extends ConsumerStatefulWidget {
  const DriverProfileForm({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.showEmail = false,
  });

  /// Shows the email field and its verification status (Verified badge, or
  /// "Verify email", which sends a code and opens [showVerifyEmailSheet]).
  /// Trip summaries are only emailed to a verified address.
  ///
  /// Edit-profile only: the onboarding Registration step leaves it off, so the
  /// signup funnel is not interrupted by a verification detour.
  final bool showEmail;

  /// Lets the hosting screen's pinned [DriverProfileSaveBar] submit this form.
  /// The form has no button of its own.
  final DriverProfileFormController controller;
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
  final _emailCtrl = TextEditingController();
  DateTime? _dob;
  bool _hasPicture = false;
  bool _marketingConsent = false;
  bool _loading = true;

  /// The email as last saved on the server, and whether that one is verified.
  /// Verification is offered for this value only - never for unsaved edits in
  /// [_emailCtrl], since the code goes to the address on the profile.
  String? _savedEmail;
  bool _emailVerified = false;
  bool _sendingCode = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(_submit);
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
      _emailCtrl.text = profile.email ?? '';
      _savedEmail = profile.email;
      _emailVerified = profile.isEmailVerified;
    }
    setState(() => _loading = false);
    widget.controller._setReady();
  }

  @override
  void dispose() {
    widget.controller._detach();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _nationalIdCtrl.dispose();
    _drivingLicenceCtrl.dispose();
    _passportCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _emailCtrl.dispose();
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
      widget.controller._setFormError('Please enter your full legal name.');
      return;
    }
    if (nationalId.isEmpty) {
      widget.controller._setFormError('Please enter your National Insurance number.');
      return;
    }
    final email = _emailCtrl.text.trim();
    if (widget.showEmail &&
        email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      widget.controller._setFormError('Please enter a valid email address.');
      return;
    }
    widget.controller._setFormError(null);

    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final ok = await ref.read(authNotifierProvider.notifier).updateProfile(
          firstName: firstName,
          lastName: lastName,
          // Off the form (onboarding) -> null, so the PATCH leaves email alone.
          email: widget.showEmail ? email : null,
          dateOfBirth: _dob,
          address: _addressCtrl.text.trim(),
          nationalIdNumber: nationalId,
          drivingLicenceNumber: _drivingLicenceCtrl.text.trim(),
          passportNumber: _passportCtrl.text.trim(),
          emergencyContactName: _emergencyNameCtrl.text.trim(),
          emergencyContactPhone: _emergencyPhoneCtrl.text.trim(),
          marketingConsent: _marketingConsent,
        );
    if (!ok) return;
    if (widget.showEmail && email.isNotEmpty && mounted) {
      // Mirrors the API: saving a different address resets verification.
      setState(() {
        if (!_sameEmail(email, _savedEmail)) _emailVerified = false;
        _savedEmail = email.toLowerCase();
      });
    }
    widget.onSubmitted();
  }

  static bool _sameEmail(String? a, String? b) =>
      (a ?? '').trim().toLowerCase() == (b ?? '').trim().toLowerCase();

  /// "Verify email": send the code, then collect it in the sheet.
  Future<void> _verifyEmail() async {
    if (_sendingCode) return;
    setState(() {
      _sendingCode = true;
      _emailError = null;
    });
    final OtpSentResult sent;
    try {
      sent = await ref.read(driverAuthServiceProvider).sendProfileEmailCode();
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingCode = false;
          _emailError = profileEmailError(e);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _sendingCode = false);

    final profile = await showVerifyEmailSheet(context, sent: sent);
    if (profile == null || !mounted) return;
    setState(() {
      _emailVerified = profile.isEmailVerified;
      _savedEmail = profile.email;
    });
    await ref.read(authNotifierProvider.notifier).adoptVerifiedProfile(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Email verified')));
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  @override
  Widget build(BuildContext context) {
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
        if (widget.showEmail) ...[
          const SizedBox(height: 12),
          _label('Email'),
          ..._emailSection(),
        ],
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
        // No button, no error text: both live in the host's pinned
        // DriverProfileSaveBar (see DriverProfileFormController).
      ],
    );
  }

  /// The email field plus whatever its verification state calls for.
  List<Widget> _emailSection() {
    final typed = _emailCtrl.text.trim();
    final saved = (_savedEmail ?? '').trim();
    final dirty = !_sameEmail(typed, saved);
    final showVerified = !dirty && saved.isNotEmpty && _emailVerified;
    final showUnverified = !dirty && saved.isNotEmpty && !_emailVerified;

    final String? hint;
    if (dirty && typed.isNotEmpty) {
      hint = 'Save your changes, then verify this email to get trip summaries by email.';
    } else if (dirty) {
      // The API ignores a blank email, so clearing the field removes nothing.
      hint = 'Leave this blank and your current email stays on your profile.';
    } else if (saved.isEmpty) {
      hint = 'Add an email to get trip summaries by email.';
    } else if (showUnverified) {
      hint = 'Verify your email to get trip summaries by email.';
    } else {
      hint = null;
    }

    return [
      McField(
        icon: 'mail',
        controller: _emailCtrl,
        editable: true,
        placeholder: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
        onChanged: (_) => setState(() => _emailError = null),
        suffix: showVerified
            ? const _EmailStatusPill(verified: true)
            : showUnverified
                ? const _EmailStatusPill(verified: false)
                : null,
      ),
      if (hint != null) ...[
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(hint, style: tw(FontWeight.w600, 12.5, Brand.sub)),
        ),
      ],
      if (showUnverified) ...[
        const SizedBox(height: 10),
        McGhostButton(
          _sendingCode ? 'Sending code…' : 'Verify email',
          icon: _sendingCode ? null : 'mail',
          full: false,
          height: 44,
          onTap: _sendingCode ? null : _verifyEmail,
        ),
      ],
      if (_emailError != null) ...[
        const SizedBox(height: 10),
        McErrorBanner(_emailError!),
      ],
    ];
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

/// "Verified" / "Unverified" pill inside the email field - the same tinted
/// pill as `StatementStatusPill` (green when done, amber when it needs action).
class _EmailStatusPill extends StatelessWidget {
  const _EmailStatusPill({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? Brand.green : Brand.star;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.094),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verified) ...[
            Ico('check', size: 13, color: color),
            const SizedBox(width: 3),
          ],
          Text(verified ? 'Verified' : 'Unverified',
              style: tw(FontWeight.w800, 11, color)),
        ],
      ),
    );
  }
}
