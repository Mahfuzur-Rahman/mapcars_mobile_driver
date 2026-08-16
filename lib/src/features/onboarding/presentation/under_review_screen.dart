import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';
import '../services/driver_documents_service.dart';

class UnderReviewScreen extends ConsumerStatefulWidget {
  const UnderReviewScreen({super.key});

  @override
  ConsumerState<UnderReviewScreen> createState() => _UnderReviewScreenState();
}

class _UnderReviewScreenState extends ConsumerState<UnderReviewScreen> {
  List<DriverDocument>? _docs;
  bool _loading = true;

  static const _requiredSpecs = [
    ('PhvLicence', 'PHV driver licence'),
    ('VehicleInsurance', 'Private hire insurance'),
    ('VehicleRegistration', 'Vehicle V5C (Logbook)'),
    ('DbsCheck', 'Enhanced DBS check'),
  ];

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    try {
      final list = await ref.read(driverDocumentsServiceProvider).list();
      if (!mounted) return;
      setState(() {
        _docs = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse('https://wa.me/447389077004');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final fullName = auth.fullName?.trim();
    final firstName = fullName != null && fullName.isNotEmpty
        ? fullName.split(' ').first
        : null;

    final greeting = firstName != null
        ? "Thanks $firstName! We're checking your documents. This usually takes 24–48 hours."
        : "Thanks! We're checking your documents. This usually takes 24–48 hours.";

    final docMap = <String, DriverDocument>{};
    for (final d in _docs ?? const <DriverDocument>[]) {
      docMap.putIfAbsent(d.type, () => d);
    }

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          child: Column(
            children: [
              Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Brand.blue.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Brand.blue, Color(0xFF12939F)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(child: Ico('clock', size: 34, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const McTitle('Application under\nreview', size: 24, align: TextAlign.center),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 290),
                    child: Text(
                      greeting,
                      textAlign: TextAlign.center,
                      style: tw(FontWeight.w600, 15, Brand.sub),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              McCard(
                padding: 16,
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      )
                    : Column(
                        children: List.generate(_requiredSpecs.length, (i) {
                          final (type, title) = _requiredSpecs[i];
                          final doc = docMap[type];
                          final status = doc?.reviewStatus;
                          final isApproved = status == 'Approved';
                          final isRejected = status == 'Rejected';
                          final isPending = status == 'Pending';

                          final (statusLabel, statusColor) = switch (status) {
                            'Approved' => ('Approved', Brand.green),
                            'Rejected' => ('Action needed', Colors.red),
                            'Pending' => ('Under review', Brand.blue),
                            _ => ('Required', Brand.faint),
                          };

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              border: i < _requiredSpecs.length - 1
                                  ? const Border(bottom: BorderSide(color: Brand.fill))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? Brand.green
                                        : isRejected
                                            ? Colors.red.withValues(alpha: 0.15)
                                            : isPending
                                                ? Brand.blue.withValues(alpha: 0.15)
                                                : Brand.fill,
                                    shape: BoxShape.circle,
                                    border: isApproved || isRejected || isPending
                                        ? null
                                        : Border.all(color: Brand.line, width: 2),
                                  ),
                                  child: isApproved
                                      ? const Center(
                                          child: Ico('check', size: 14, color: Colors.white))
                                      : isRejected
                                          ? const Center(
                                              child: Ico('x', size: 12, color: Colors.red))
                                          : isPending
                                              ? const Center(
                                                  child: Ico('clock', size: 12, color: Brand.blue))
                                              : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: tw(
                                      FontWeight.w700,
                                      14.5,
                                      isApproved ? Brand.ink : Brand.sub,
                                    ),
                                  ),
                                ),
                                Text(
                                  statusLabel,
                                  style: tw(FontWeight.w800, 12, statusColor),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: McGhostButton(
                      'My documents',
                      icon: 'doc',
                      onTap: () => context.push('/documents'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: McGhostButton(
                      'Support',
                      icon: 'msg',
                      onTap: _contactSupport,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              McButton('Continue to home', kind: BtnKind.grad, onTap: () => context.go('/home')),
            ],
          ),
        ),
      ),
    );
  }
}
