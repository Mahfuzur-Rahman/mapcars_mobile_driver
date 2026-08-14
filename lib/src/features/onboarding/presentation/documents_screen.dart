import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../auth/services/driver_auth_service.dart';
import '../services/driver_documents_service.dart';

/// (DocumentType enum name, title, helper text).
typedef _DocSpec = (String type, String title, String hint);

const List<_DocSpec> _required = [
  ('PhvLicence', 'PHV driver licence', 'TfL private hire driver licence'),
  ('VehicleInsurance', 'Private hire insurance', 'Valid insurance certificate'),
  ('VehicleRegistration', 'Vehicle V5C', 'Logbook / registration document'),
  ('DbsCheck', 'DBS check', 'Enhanced DBS certificate'),
];

const List<_DocSpec> _vehiclePhotos = [
  ('VehicleFrontPhoto', 'Vehicle — front', 'Clear photo of the front'),
  ('VehicleRearPhoto', 'Vehicle — rear', 'Clear photo of the rear'),
  ('VehicleInteriorPhoto', 'Vehicle — interior', 'Front and rear seats'),
];

/// Extra evidence an admin may ask for — not required to submit for review,
/// but speeds up approval.
const List<_DocSpec> _additional = [
  ('Passport', 'Passport', 'Photo page of a valid passport'),
  ('DrivingLicence', 'Driving licence', 'DVLA photocard, front and back'),
  ('VehicleBadge', 'Vehicle PHV badge', "The vehicle's own licence disc/plate"),
  ('BankStatement', 'Bank statement', 'Recent statement for payouts'),
  ('ProofOfAddress', 'Utility bill', 'Dated within the last 3 months'),
];

/// DocumentType names the API requires an `expiresOn` date for — the vehicle
/// photos, bank statement and utility bill never expire.
final Set<String> _expiringTypes = {
  ..._required.map((d) => d.$1),
  'Passport',
  'DrivingLicence',
  'VehicleBadge',
};

const _red = Color(0xFFDC2626);

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  /// Latest uploaded document per DocumentType name.
  final Map<String, DriverDocument> _byType = {};
  bool _loading = true;
  String? _uploadingType;
  bool _hasPicture = false;
  bool _uploadingPicture = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await ref.read(driverDocumentsServiceProvider).list();
      _byType.clear();
      // List is newest-first — keep the first (latest) seen per type.
      for (final d in docs) {
        _byType.putIfAbsent(d.type, () => d);
      }
    } on ApiException {
      // No session yet (e.g. prototype browsing) — show the empty upload state.
    }

    final profile = await ref.read(authNotifierProvider.notifier).loadProfile();
    if (!mounted) return;
    setState(() {
      _hasPicture = profile?.hasProfilePicture ?? false;
      _loading = false;
    });
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

    setState(() => _uploadingPicture = true);
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .uploadProfilePicture(File(picked.path));
    if (!mounted) return;
    setState(() {
      _uploadingPicture = false;
      if (ok) _hasPicture = true;
    });
  }

  Future<DateTime?> _pickExpiry() {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
  }

  Future<void> _pick(String type) async {
    if (_uploadingType != null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    DateTime? expiresOn;
    if (_expiringTypes.contains(type)) {
      expiresOn = await _pickExpiry();
      if (expiresOn == null) {
        _toast('An expiry date is required for this document.');
        return;
      }
    }

    setState(() => _uploadingType = type);
    try {
      final doc = await ref
          .read(driverDocumentsServiceProvider)
          .upload(type, File(path), expiresOn: expiresOn);
      if (mounted) setState(() => _byType[type] = doc);
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not upload the file. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _allRequiredUploaded =>
      _hasPicture && _required.every((d) => _byType.containsKey(d.$1));

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
                  const McNavHeader(title: 'Upload documents', fallback: '/home', showMenu: false),
                  const SizedBox(height: 8),
                  Text('We verify these to keep riders safe. JPG, PNG or PDF.',
                      style: tw(FontWeight.w600, 14, Brand.sub)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Profile picture'),
                          _pictureCard(),
                          const SizedBox(height: 20),
                          _sectionLabel('Required documents'),
                          for (final d in _required) ...[
                            _docCard(d),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          _sectionLabel('Vehicle photos'),
                          for (final d in _vehiclePhotos) ...[
                            _docCard(d),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          _sectionLabel('Additional documents'),
                          for (final d in _additional) ...[
                            _docCard(d),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: _allRequiredUploaded ? 1 : 0.5,
                            child: McButton(
                              'Submit for review',
                              icon: 'check',
                              kind: BtnKind.grad,
                              onTap: _allRequiredUploaded
                                  ? () => context.go('/under-review')
                                  : () => _toast(!_hasPicture
                                      ? 'Add a profile picture first.'
                                      : 'Upload all required documents first.'),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(text.toUpperCase(),
            style: tw(FontWeight.w800, 11.5, Brand.faint, 0.6)),
      );

  Widget _pictureCard() {
    final token = ref.watch(authTokenProvider);

    return GestureDetector(
      onTap: _uploadingPicture ? null : _pickPicture,
      child: McCard(
        padding: 14,
        color: _hasPicture ? Brand.green.withValues(alpha: 0.047) : null,
        border: _hasPicture ? Brand.green.withValues(alpha: 0.33) : null,
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: _uploadingPicture
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  : _hasPicture && token != null
                      ? ClipOval(
                          child: Image.network(
                            ref.read(driverAuthServiceProvider).profilePictureUrl(Env.apiBaseUrl),
                            headers: {'Authorization': 'Bearer $token'},
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => const McAvatar(size: 44),
                          ),
                        )
                      : const McAvatar(size: 44),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A clear photo of your face', style: tw(FontWeight.w900, 14.5, Brand.ink)),
                  const SizedBox(height: 2),
                  Text(
                    _uploadingPicture
                        ? 'Uploading…'
                        : _hasPicture
                            ? 'Added · tap to change'
                            : 'Required for approval',
                    style: tw(FontWeight.w600, 12.5, _hasPicture ? Brand.green : Brand.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!_uploadingPicture) Ico(_hasPicture ? 'chevR' : 'camera', size: 20, color: Brand.faint),
          ],
        ),
      ),
    );
  }

  Widget _docCard(_DocSpec spec) {
    final (type, title, hint) = spec;
    final doc = _byType[type];
    final uploading = _uploadingType == type;

    final approved = doc?.reviewStatus == 'Approved';
    final rejected = doc?.reviewStatus == 'Rejected';
    final uploaded = doc != null;

    final (String iconName, Color iconBg, Color iconColor) = approved
        ? ('check', Brand.green, Colors.white)
        : rejected
            ? ('upload', _red.withValues(alpha: 0.12), _red)
            : uploaded
                ? ('doc', Brand.fill, Brand.sub)
                : ('upload', Brand.fill, Brand.sub);

    final String? expirySuffix = doc?.expiresOn == null
        ? null
        : ' · Exp ${doc!.expiresOn!.day.toString().padLeft(2, '0')}/${doc.expiresOn!.month.toString().padLeft(2, '0')}/${doc.expiresOn!.year}';

    final String sub = uploading
        ? 'Uploading…'
        : rejected
            ? 'Rejected · tap to re-upload'
            : approved
                ? 'Approved${expirySuffix ?? ''}'
                : uploaded
                    ? 'Uploaded · in review${expirySuffix ?? ''}'
                    : hint;

    final Color subColor = rejected
        ? _red
        : approved
            ? Brand.green
            : Brand.sub;

    return GestureDetector(
      onTap: uploading ? null : () => _pick(type),
      child: McCard(
        padding: 14,
        color: approved ? Brand.green.withValues(alpha: 0.047) : null,
        border: approved
            ? Brand.green.withValues(alpha: 0.33)
            : rejected
                ? _red.withValues(alpha: 0.4)
                : uploaded
                    ? Brand.blue
                    : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Ico(iconName, size: 22, color: iconColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tw(FontWeight.w900, 14.5, Brand.ink)),
                  const SizedBox(height: 2),
                  Text(sub, style: tw(FontWeight.w600, 12.5, subColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (approved)
              Text('✓', style: tw(FontWeight.w800, 14, Brand.green))
            else if (!uploading)
              Ico(uploaded ? 'chevR' : 'plus', size: 20, color: Brand.faint),
          ],
        ),
      ),
    );
  }
}
