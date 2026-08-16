import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/mc.dart';
import '../../drive/services/trip_service.dart';
import '../providers/driver_trips_provider.dart';
import '../services/payout_service.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  PayoutAccount? _account;
  bool _loadingAccount = true;
  bool _startingOnboarding = false;
  String? _error;
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final account = await ref.read(payoutServiceProvider).getAccountStatus();
      if (mounted) {
        setState(() {
          _account = account;
          _loadingAccount = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAccount = false);
    }
  }

  void _showCashOutModal(double amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Ico('check', size: 28, color: Brand.green),
              ),
            ),
            const SizedBox(height: 16),
            const McTitle('Instant Cash Out Sent', size: 22),
            const SizedBox(height: 8),
            Text(
              'Transferred ${formatGbp((amount * 100).round())} to your linked bank account.',
              textAlign: TextAlign.center,
              style: tw(FontWeight.w600, 14, Brand.sub),
            ),
            const SizedBox(height: 24),
            McButton('Done', kind: BtnKind.green, onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _setUpPayouts() async {
    setState(() {
      _startingOnboarding = true;
      _error = null;
    });
    try {
      final target = '${Env.apiBaseUrl}/health';
      final url = await ref.read(payoutServiceProvider).startOnboarding(
            refreshUrl: target,
            returnUrl: target,
          );
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        setState(() => _error = "Couldn't open the payout setup page.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            e is ApiException ? e.message : "Couldn't start payout setup. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _startingOnboarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(driverTripsProvider);

    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _DriverTabBar(active: 'earn'),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverTripsProvider);
            await _loadAccount();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: tripsAsync.when(
              data: (trips) => _buildBody(context, trips),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text("Couldn't load your earnings.",
                      style: tw(FontWeight.w700, 14, Brand.sub)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Trip> trips) {
    final completed = trips.where((t) => t.status == TripStatus.completed).toList();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final thisWeek = completed
        .where((t) => (t.completedAtUtc ?? t.createdAtUtc).isAfter(weekAgo))
        .toList();

    double sumEarnings(List<Trip> ts) =>
        ts.fold(0.0, (sum, t) => sum + (t.driverEarnings ?? 0));
    double sumTips(List<Trip> ts) => ts.fold(0.0, (sum, t) => sum + t.tipAmount);

    final weekEarnings = sumEarnings(thisWeek);
    final weekTips = sumTips(thisWeek);
    final weekTripEarnings = weekEarnings - weekTips;

    // Per-day totals for the last 7 days (Monday first).
    const dayFullNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dayTotals = List<double>.filled(7, 0);
    for (final t in thisWeek) {
      final day = t.completedAtUtc ?? t.createdAtUtc;
      final idx = day.weekday - 1; // Monday = 0
      if (idx >= 0 && idx < 7) dayTotals[idx] += t.driverEarnings ?? 0;
    }
    final maxDay = dayTotals.fold(0.0, (m, v) => v > m ? v : m);
    final selIdx = _selectedDayIndex ?? (now.weekday - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: McNavHeader(title: 'Earnings', fallback: '/home')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Brand.paper,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Brand.line, width: 1.5),
              ),
              child: Text('This week', style: tw(FontWeight.w800, 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Hero card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: Brand.gradBlueGreen,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Brand.blue.withValues(alpha: 0.3),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Earned this week',
                    style: tw(FontWeight.w800, 13, Colors.white.withValues(alpha: 0.85)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${dayFullNames[selIdx]}: ${formatGbp((dayTotals[selIdx] * 100).round())}',
                      style: tw(FontWeight.w800, 11, Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(formatGbp((weekEarnings * 100).round()),
                  style: tw(FontWeight.w900, 38, Colors.white, -1)),
              const SizedBox(height: 14),
              SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _selectedDayIndex = i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: 8 + 48 * (maxDay == 0 ? 0 : dayTotals[i] / maxDay),
                                decoration: BoxDecoration(
                                  color: i == selIdx
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(5),
                                  border: i == selIdx
                                      ? Border.all(color: Brand.lime, width: 1.5)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                dayLabels[i],
                                style: tw(
                                  FontWeight.w800,
                                  10,
                                  i == selIdx
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingAccount)
          const SizedBox(
            height: 46,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (_account?.payoutsEnabled != true)
          McButton(
            _startingOnboarding ? 'Opening…' : 'Set up payouts',
            icon: 'bank',
            kind: BtnKind.green,
            onTap: _startingOnboarding ? null : _setUpPayouts,
          )
        else
          Row(
            children: [
              Expanded(
                child: Text('Payouts sent automatically by Stripe.',
                    style: tw(FontWeight.w700, 13, Brand.sub)),
              ),
              const SizedBox(width: 8),
              McGhostButton(
                'Cash out',
                icon: 'bank',
                // The driver's real balance — this used to fall back to £62.40
                // and tell a driver who'd earned nothing that it had been sent.
                onTap: weekEarnings > 0
                    ? () => _showCashOutModal(weekEarnings)
                    : null,
              ),
            ],
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: tw(FontWeight.w600, 12.5, Colors.red)),
        ],
        const SizedBox(height: 16),
        // Breakdown rows
        _breakdownRow('nav', 'Trip earnings', formatGbp((weekTripEarnings * 100).round()),
            divider: true),
        _breakdownRow('gift', 'Tips', formatGbp((weekTips * 100).round()), divider: false),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${thisWeek.length} trips this week',
                style: tw(FontWeight.w700, 13, Brand.sub)),
            GestureDetector(
              onTap: () => context.push('/payouts'),
              child: Text('View detail', style: tw(FontWeight.w800, 13, Brand.blue)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _breakdownRow(String icon, String label, String value, {required bool divider}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: Brand.fill))
            : null,
      ),
      child: Row(
        children: [
          Ico(icon, size: 20, color: Brand.sub),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: tw(FontWeight.w700, 15))),
          Text(value, style: tw(FontWeight.w900, 15)),
        ],
      ),
    );
  }
}

class _DriverTabBar extends StatelessWidget {
  const _DriverTabBar({required this.active});
  final String active;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String, String)>[
      ('wheel', 'Drive', 'drive', '/home'),
      ('chart', 'Earnings', 'earn', '/earnings'),
      ('user', 'Account', 'account', '/profile'),
    ];
    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: Brand.paper,
        border: Border(top: BorderSide(color: Brand.fill)),
      ),
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          for (final (ic, label, key, route) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go(route),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Ico(ic, size: 24, color: key == active ? Brand.blue : Brand.faint),
                    const SizedBox(height: 3),
                    Text(label,
                        style: tw(FontWeight.w800, 11,
                            key == active ? Brand.blue : Brand.faint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
