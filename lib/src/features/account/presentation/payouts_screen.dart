import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/mc.dart';
import '../../drive/services/trip_service.dart';
import '../providers/driver_trips_provider.dart';
import '../services/payout_service.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  PayoutAccount? _account;
  List<Payout>? _payouts;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ref.read(payoutServiceProvider).getAccountStatus(),
        ref.read(payoutServiceProvider).listPayouts(),
      ]);
      if (!mounted) return;
      setState(() {
        _account = results[0] as PayoutAccount;
        _payouts = results[1] as List<Payout>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : "Couldn't load your payouts.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(driverTripsProvider);
    final now = DateTime.now();
    final todaysTrips = (tripsAsync.asData?.value ?? const <Trip>[])
        .where((t) =>
            t.status == TripStatus.completed &&
            _isSameDay(t.completedAtUtc ?? t.createdAtUtc, now))
        .toList();
    final payoutsEnabled = _account?.payoutsEnabled ?? false;

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McNavHeader(title: 'Earnings detail', fallback: '/earnings'),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Text(_error!, style: tw(FontWeight.w600, 13, Colors.red))
              else ...[
                // Account status card — Stripe pays out automatically once
                // connected; there's no manual "cash out" or next-payout-date
                // exposed by the account status endpoint.
                McCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: payoutsEnabled ? Brand.green.withValues(alpha: 0.094) : Brand.fill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Ico('bank', size: 22,
                              color: payoutsEnabled ? Brand.green : Brand.sub),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(payoutsEnabled ? 'Payouts active' : 'Payouts not set up',
                                style: tw(FontWeight.w900, 15)),
                            Text(
                              payoutsEnabled
                                  ? 'Sent automatically to your bank'
                                  : 'Finish setup from the Earnings screen',
                              style: tw(FontWeight.w600, 12.5, Brand.sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionLabel('PAYOUT HISTORY'),
                const SizedBox(height: 10),
                if ((_payouts ?? const []).isEmpty)
                  Text('No payouts yet.', style: tw(FontWeight.w700, 13, Brand.sub))
                else
                  for (int i = 0; i < _payouts!.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    McCard(
                      padding: 13,
                      child: Row(
                        children: [
                          const Ico('bank', size: 20, color: Brand.sub),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatGbp((_payouts![i].amount * 100).round()),
                                    style: tw(FontWeight.w900, 15)),
                                Text(formatShortDate(_payouts![i].createdAtUtc),
                                    style: tw(FontWeight.w600, 12, Brand.sub)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Brand.green.withValues(alpha: 0.094),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(_titleCase(_payouts![i].status),
                                style: tw(FontWeight.w800, 11, Brand.green)),
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
              const SizedBox(height: 18),
              _sectionLabel("TODAY'S TRIPS"),
              const SizedBox(height: 8),
              if (todaysTrips.isEmpty)
                Text('No trips completed today yet.', style: tw(FontWeight.w700, 13, Brand.sub))
              else
                for (int i = 0; i < todaysTrips.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                    decoration: BoxDecoration(
                      border: i < todaysTrips.length - 1
                          ? const Border(bottom: BorderSide(color: Brand.fill))
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Ico('nav', size: 18, color: Brand.sub),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(todaysTrips[i].pickupAddress, style: tw(FontWeight.w800, 14)),
                              Text(
                                formatRelativeDateTime(
                                    todaysTrips[i].completedAtUtc ?? todaysTrips[i].createdAtUtc),
                                style: tw(FontWeight.w600, 12, Brand.sub),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatGbp(((todaysTrips[i].driverEarnings ?? 0) * 100).round()),
                          style: tw(FontWeight.w900, 14, Brand.green),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      Text(text, style: tw(FontWeight.w800, 12, Brand.sub, 0.5));

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}
