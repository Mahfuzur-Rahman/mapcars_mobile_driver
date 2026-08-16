import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/mc.dart';
import '../services/vehicle_service.dart';

class VehicleTierScreen extends ConsumerStatefulWidget {
  const VehicleTierScreen({super.key});

  @override
  ConsumerState<VehicleTierScreen> createState() => _VehicleTierScreenState();
}

class _VehicleTierScreenState extends ConsumerState<VehicleTierScreen> {
  Vehicle? _vehicle;
  List<TierAppeal> _appeals = [];
  bool _loading = true;
  String? _error;

  // Appeal submission state
  String _selectedTier = 'comfort';
  final TextEditingController _reasonCtrl = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _submitting = false;
  String? _submitError;
  String? _submitSuccess;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vehicleFuture = ref.read(vehicleServiceProvider).getMine();
      final appealsFuture = ref.read(vehicleServiceProvider).getAppeals();

      final results = await Future.wait([vehicleFuture, appealsFuture]);
      if (!mounted) return;

      final vehicle = results[0] as Vehicle?;
      final appeals = results[1] as List<TierAppeal>;

      setState(() {
        _vehicle = vehicle;
        _appeals = appeals;
        _loading = false;

        final current = vehicle?.tier ?? 'economy';
        if (current == 'economy') {
          _selectedTier = 'comfort';
        } else if (current == 'comfort') {
          _selectedTier = 'premium';
        } else {
          _selectedTier = 'premium';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load vehicle tier information.';
        _loading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (photo != null && mounted) {
          setState(() => _selectedPhotos.add(photo));
        }
      } else {
        final photos = await _picker.pickMultiImage(imageQuality: 80);
        if (photos.isNotEmpty && mounted) {
          setState(() => _selectedPhotos.addAll(photos));
        }
      }
    } catch (_) {
      // Ignored if user cancels
    }
  }

  void _removePhoto(int index) {
    setState(() => _selectedPhotos.removeAt(index));
  }

  Future<void> _submitAppeal() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _submitError = 'Please explain why your vehicle qualifies for this tier.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
      _submitSuccess = null;
    });

    try {
      final photoPaths = _selectedPhotos.map((f) => f.path).toList();
      await ref.read(vehicleServiceProvider).submitAppeal(
            requestedTier: _selectedTier,
            reason: reason,
            photoPaths: photoPaths.isNotEmpty ? photoPaths : null,
          );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitSuccess = 'Appeal submitted successfully! Admin will review it shortly.';
        _reasonCtrl.clear();
        _selectedPhotos.clear();
      });

      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e is ApiException ? e.message : 'Failed to submit appeal. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    final pendingAppeal = _appeals.where((a) => a.isPending).firstOrNull;
    final pastAppeals = _appeals.where((a) => !a.isPending).toList();

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Ico('chevL', size: 22, color: Brand.ink),
                  ),
                  const SizedBox(width: 12),
                  const McTitle('Vehicle Tier & Appeal', size: 20),
                  const Spacer(),
                  const McMenuButton(),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Brand.errorBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Brand.errorBorder),
                                ),
                                child: Text(_error!, style: tw(FontWeight.w600, 13, Brand.errorText)),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Current Vehicle Tier Card
                            _buildCurrentTierCard(vehicle),
                            const SizedBox(height: 20),

                            // Active Pending Appeal Banner
                            if (pendingAppeal != null) ...[
                              _buildPendingAppealCard(pendingAppeal),
                              const SizedBox(height: 20),
                            ],

                            // Tier Comparison Guide
                            _buildTiersGuide(),
                            const SizedBox(height: 20),

                            // Submit Appeal Section (only if no pending appeal)
                            if (pendingAppeal == null && vehicle != null) ...[
                              _buildAppealForm(vehicle.tier),
                              const SizedBox(height: 20),
                            ],

                            // Past Appeals History
                            if (pastAppeals.isNotEmpty) ...[
                              Text('APPEAL HISTORY', style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
                              const SizedBox(height: 10),
                              for (final appeal in pastAppeals) ...[
                                _buildPastAppealItem(appeal),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTierCard(Vehicle? vehicle) {
    final tier = vehicle?.tier ?? 'economy';
    final tierInfo = _getTierConfig(tier);

    return McCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tierInfo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Ico(tierInfo.icon, size: 24, color: tierInfo.color),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ASSIGNED VEHICLE TIER', style: tw(FontWeight.w800, 11, Brand.sub, 0.5)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(tierInfo.name, style: tw(FontWeight.w900, 18, Brand.ink)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tierInfo.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${tierInfo.multiplier}x Fare',
                            style: tw(FontWeight.w800, 11, tierInfo.color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Brand.line),
          const SizedBox(height: 12),
          if (vehicle != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${vehicle.make} ${vehicle.model} (${vehicle.year})',
                    style: tw(FontWeight.w700, 13, Brand.ink)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Brand.fill,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(vehicle.registrationNumber,
                      style: tw(FontWeight.w800, 12, Brand.ink, 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Set by admin based on your car specifications and documents.',
              style: tw(FontWeight.w600, 12, Brand.sub),
            ),
          ] else ...[
            Text('No vehicle registered yet. Add your vehicle in profile first.',
                style: tw(FontWeight.w600, 12, Brand.sub)),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingAppealCard(TierAppeal appeal) {
    final requestedInfo = _getTierConfig(appeal.requestedTier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Ico('clock', size: 16, color: Colors.amber),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tier Appeal Under Review',
                        style: tw(FontWeight.w900, 14, Colors.amber.shade900)),
                    Text('Requested: ${requestedInfo.name}',
                        style: tw(FontWeight.w700, 12, Colors.amber.shade800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your reason: "${appeal.reason}"',
            style: tw(FontWeight.w600, 12, Colors.amber.shade900),
          ),
          const SizedBox(height: 6),
          Text(
            'Our admin team is currently reviewing your vehicle details. You will receive an email and push notification when a decision is made.',
            style: tw(FontWeight.w500, 11.5, Colors.amber.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildTiersGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TIER ELIGIBILITY GUIDE', style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTierGuideItem('economy', 'Economy', '1.0x', 'Standard 4-door')),
            const SizedBox(width: 8),
            Expanded(child: _buildTierGuideItem('comfort', 'Comfort', '1.35x', 'Newer, spacious')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTierGuideItem('xl', 'XL', '1.7x', '6+ seats')),
            const SizedBox(width: 8),
            Expanded(child: _buildTierGuideItem('premium', 'Premium', '2.1x', 'Executive luxury')),
          ],
        ),
      ],
    );
  }

  Widget _buildTierGuideItem(String tierKey, String name, String mult, String desc) {
    final conf = _getTierConfig(tierKey);
    final isCurrent = (_vehicle?.tier ?? 'economy') == tierKey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? conf.color.withValues(alpha: 0.08) : Brand.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? conf.color : Brand.line.withValues(alpha: 0.6),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: tw(FontWeight.w900, 13.5, Brand.ink)),
              Text(mult, style: tw(FontWeight.w800, 12, conf.color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: tw(FontWeight.w600, 11, Brand.sub)),
        ],
      ),
    );
  }

  Widget _buildAppealForm(String currentTier) {
    final availableTiers = ['comfort', 'xl', 'premium']
        .where((t) => t != currentTier.toLowerCase())
        .toList();

    return McCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REQUEST TIER CHANGE', style: tw(FontWeight.w900, 15, Brand.ink)),
          const SizedBox(height: 4),
          Text(
            'If you believe your car qualifies for a higher ride tier, submit an appeal for admin review.',
            style: tw(FontWeight.w600, 12, Brand.sub),
          ),
          const SizedBox(height: 16),

          Text('Select Requested Tier', style: tw(FontWeight.w800, 12, Brand.sub)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final t in availableTiers) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTier = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTier == t ? Brand.ink : Brand.fill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          _getTierConfig(t).name,
                          style: tw(
                            FontWeight.w800,
                            12.5,
                            _selectedTier == t ? Colors.white : Brand.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (t != availableTiers.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),

          Text('Justification & Vehicle Details *', style: tw(FontWeight.w800, 12, Brand.sub)),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            style: tw(FontWeight.w600, 13, Brand.ink),
            decoration: InputDecoration(
              hintText: 'e.g. 2024 model with full leather interior, extra legroom, pristine condition...',
              hintStyle: tw(FontWeight.w500, 12, Brand.faint),
              filled: true,
              fillColor: Brand.fill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

          // Optional Photos Upload
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Car Photos (Optional)', style: tw(FontWeight.w800, 12, Brand.sub)),
              Text('Interior / Seats / Exterior', style: tw(FontWeight.w600, 11, Brand.faint)),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedPhotos.isNotEmpty) ...[
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPhotos.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  if (idx == _selectedPhotos.length) {
                    return _buildAddPhotoButton();
                  }
                  final file = _selectedPhotos[idx];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(file.path),
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removePhoto(idx),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Ico('gallery', size: 16, color: Brand.blue),
                    label: Text('Add from Gallery', style: tw(FontWeight.w700, 12, Brand.blue)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Brand.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Ico('camera', size: 16, color: Brand.ink),
                    label: Text('Take Photo', style: tw(FontWeight.w700, 12, Brand.ink)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Brand.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(_submitError!, style: tw(FontWeight.w700, 12.5, Colors.red)),
          ],

          if (_submitSuccess != null) ...[
            const SizedBox(height: 12),
            Text(_submitSuccess!, style: tw(FontWeight.w700, 12.5, Colors.green)),
          ],

          const SizedBox(height: 18),
          McButton(
            _submitting ? 'Submitting Appeal…' : 'Submit Appeal to Admin',
            icon: _submitting ? null : 'send',
            onTap: _submitting ? null : _submitAppeal,
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Brand.fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Brand.line, style: BorderStyle.solid),
        ),
        child: const Center(
          child: Ico('plus', size: 22, color: Brand.sub),
        ),
      ),
    );
  }

  Widget _buildPastAppealItem(TierAppeal appeal) {
    final statusColor = appeal.isApproved
        ? Colors.green
        : appeal.isRejected
            ? Colors.red
            : Colors.amber;

    return McCard(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(appeal.currentTier.toUpperCase(),
                      style: tw(FontWeight.w800, 12, Brand.sub)),
                  const SizedBox(width: 4),
                  const Ico('turn', size: 12, color: Brand.faint),
                  const SizedBox(width: 4),
                  Text(appeal.requestedTier.toUpperCase(),
                      style: tw(FontWeight.w900, 13, Brand.ink)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  appeal.status,
                  style: tw(FontWeight.w800, 11, statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Reason: ${appeal.reason}', style: tw(FontWeight.w600, 12, Brand.ink)),
          if (appeal.adminNotes != null && appeal.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Admin note: ${appeal.adminNotes}',
              style: tw(FontWeight.w600, 11.5, Brand.sub),
            ),
          ],
        ],
      ),
    );
  }

  _TierConfig _getTierConfig(String tier) {
    switch (tier.toLowerCase()) {
      case 'comfort':
        return const _TierConfig('Comfort', '1.35', 'car', Brand.blue);
      case 'xl':
        return const _TierConfig('XL', '1.7', 'car', Brand.green);
      case 'premium':
        return const _TierConfig('Premium', '2.1', 'bolt', Colors.amber);
      case 'economy':
      default:
        return const _TierConfig('Economy', '1.0', 'car', Brand.sub);
    }
  }
}

class _TierConfig {
  const _TierConfig(this.name, this.multiplier, this.icon, this.color);
  final String name;
  final String multiplier;
  final String icon;
  final Color color;
}
