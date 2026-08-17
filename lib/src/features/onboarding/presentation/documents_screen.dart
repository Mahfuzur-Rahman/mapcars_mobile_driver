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
  /// All uploaded documents grouped by DocumentType.
  final Map<String, List<DriverDocument>> _docsByType = {};
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
      _docsByType.clear();
      for (final d in docs) {
        _docsByType.putIfAbsent(d.type, () => []).add(d);
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
      if (mounted) {
        setState(() {
          _docsByType.putIfAbsent(type, () => []).insert(0, doc);
        });
        _toast('Document uploaded successfully!');
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not upload the file. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  Future<void> _requestDeletionDialog(DriverDocument doc, String title) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Request Deletion', style: tw(FontWeight.w900, 16, Brand.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document: $title', style: tw(FontWeight.w700, 13, Brand.ink)),
            Text(doc.originalFileName, style: tw(FontWeight.w500, 12, Brand.sub)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'Drivers cannot delete documents directly. Submitting this request sends it to admin for review.',
                style: tw(FontWeight.w600, 11.5, Colors.amber.shade900),
              ),
            ),
            const SizedBox(height: 14),
            Text('Reason (Optional)', style: tw(FontWeight.w700, 12, Brand.ink)),
            const SizedBox(height: 4),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: tw(FontWeight.w500, 12.5, Brand.ink),
              decoration: InputDecoration(
                hintText: 'e.g. Uploaded wrong file, replacing with renewed licence...',
                hintStyle: tw(FontWeight.w500, 12, Brand.faint),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: tw(FontWeight.w700, 13, Brand.sub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Submit Request', style: tw(FontWeight.w700, 13, Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(driverDocumentsServiceProvider)
            .requestDeletion(doc.id, reason: reasonController.text);
        _toast('Deletion request submitted to admin.');
        await _load();
      } catch (e) {
        _toast('Failed to submit deletion request.');
      }
    }
  }

  void _previewDocument(DriverDocument doc, String title) {
    final token = ref.read(authTokenProvider);
    final contentUrl =
        ref.read(driverDocumentsServiceProvider).getDocumentContentUrl(doc.id);
    final isPdf = doc.originalFileName.toLowerCase().endsWith('.pdf');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: tw(FontWeight.w900, 15, Brand.ink)),
                        Text(doc.originalFileName,
                            style: tw(FontWeight.w600, 11, Brand.sub),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: isPdf
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf,
                                color: Colors.white, size: 48),
                            const SizedBox(height: 8),
                            Text('PDF Document',
                                style: tw(FontWeight.w700, 14, Colors.white)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(doc.originalFileName,
                                  style: tw(
                                      FontWeight.w500, 12, Colors.white70),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      )
                    : Image.network(
                        contentUrl,
                        headers: token != null
                            ? {'Authorization': 'Bearer $token'}
                            : null,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white));
                        },
                        errorBuilder: (context, error, stack) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image,
                                  color: Colors.white54, size: 40),
                              const SizedBox(height: 6),
                              Text('Preview unavailable',
                                  style: tw(
                                      FontWeight.w600, 12, Colors.white70)),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _allRequiredUploaded =>
      _hasPicture &&
      _required.every((d) => (_docsByType[d.$1] ?? []).isNotEmpty);

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
                  const McNavHeader(
                      title: 'Upload documents', fallback: '/home', showMenu: false),
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
                            _docCategorySection(d),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          _sectionLabel('Vehicle photos'),
                          for (final d in _vehiclePhotos) ...[
                            _docCategorySection(d),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          _sectionLabel('Additional documents'),
                          for (final d in _additional) ...[
                            _docCategorySection(d),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 14),
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
                            ref
                                .read(driverAuthServiceProvider)
                                .profilePictureUrl(Env.apiBaseUrl),
                            headers: {'Authorization': 'Bearer $token'},
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                const McAvatar(size: 44),
                          ),
                        )
                      : const McAvatar(size: 44),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A clear photo of your face',
                      style: tw(FontWeight.w900, 14.5, Brand.ink)),
                  const SizedBox(height: 2),
                  Text(
                    _uploadingPicture
                        ? 'Uploading…'
                        : _hasPicture
                            ? 'Added · tap to change'
                            : 'Required for approval',
                    style: tw(FontWeight.w600, 12.5,
                        _hasPicture ? Brand.green : Brand.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!_uploadingPicture)
              Ico(_hasPicture ? 'chevR' : 'camera',
                  size: 20, color: Brand.faint),
          ],
        ),
      ),
    );
  }

  Widget _docCategorySection(_DocSpec spec) {
    final (type, title, hint) = spec;
    final docs = _docsByType[type] ?? [];
    final uploading = _uploadingType == type;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: docs.isNotEmpty
              ? Brand.blue.withValues(alpha: 0.3)
              : Brand.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header & Upload Action
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tw(FontWeight.w900, 14.5, Brand.ink)),
                      const SizedBox(height: 2),
                      Text(hint, style: tw(FontWeight.w500, 12, Brand.sub)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: uploading ? null : () => _pick(type),
                  icon: uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline, size: 16),
                  label: Text(
                    docs.isEmpty ? 'Upload' : 'Add Another',
                    style: tw(FontWeight.w700, 12, Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Brand.blue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(60, 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // Uploaded Files List under this category
          if (docs.isNotEmpty) ...[
            const Divider(height: 1, color: Brand.line),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: docs.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 14, endIndent: 14, color: Brand.line),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _docItemRow(doc, title);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _docItemRow(DriverDocument doc, String categoryTitle) {
    final approved = doc.reviewStatus == 'Approved';
    final rejected = doc.reviewStatus == 'Rejected';

    final (String statusLabel, Color statusColor, Color statusBg) =
        doc.isDeletionRequested
            ? ('Deletion Requested', _red, _red.withValues(alpha: 0.1))
            : approved
                ? ('Approved', Brand.green, Brand.green.withValues(alpha: 0.1))
                : rejected
                    ? ('Rejected', _red, _red.withValues(alpha: 0.1))
                    : ('In Review', Colors.amber.shade900, Colors.amber.shade50);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 20, color: Brand.sub),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.originalFileName,
                  style: tw(FontWeight.w700, 12.5, Brand.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: tw(FontWeight.w800, 10, statusColor),
                      ),
                    ),
                    if (doc.expiresOn != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Exp: ${doc.expiresOn!.day}/${doc.expiresOn!.month}/${doc.expiresOn!.year}',
                        style: tw(FontWeight.w500, 11, Brand.sub),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // View Button
          TextButton(
            onPressed: () => _previewDocument(doc, categoryTitle),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(40, 30),
            ),
            child: Text('View', style: tw(FontWeight.w700, 12, Brand.blue)),
          ),
          // Request Deletion Button
          OutlinedButton(
            onPressed: doc.isDeletionRequested
                ? null
                : () => _requestDeletionDialog(doc, categoryTitle),
            style: OutlinedButton.styleFrom(
              foregroundColor: _red,
              side: BorderSide(
                color: doc.isDeletionRequested
                    ? Brand.line
                    : _red.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(50, 30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              doc.isDeletionRequested ? 'Pending' : 'Delete',
              style: tw(
                FontWeight.w700,
                11.5,
                doc.isDeletionRequested ? Brand.faint : _red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
