import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bars = <(String, double)>[
      ('M', 0.5),
      ('T', 0.7),
      ('W', 0.45),
      ('T', 0.85),
      ('F', 1.0),
      ('S', 0.6),
      ('S', 0.3),
    ];

    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _DriverTabBar(active: 'earn'),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const McTitle('Earnings', size: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Brand.paper,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Brand.line, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('This week', style: tw(FontWeight.w800, 13)),
                        const SizedBox(width: 6),
                        const Ico('chevD', size: 14, color: Brand.sub),
                      ],
                    ),
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
                    Text('Available to cash out',
                        style: tw(FontWeight.w800, 13, Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 2),
                    Text('£342.60', style: tw(FontWeight.w900, 38, Colors.white, -1)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 70,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (int i = 0; i < bars.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: 56 * bars[i].$2,
                                    decoration: BoxDecoration(
                                      color: i == 4
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(bars[i].$1,
                                      style: tw(FontWeight.w800, 10,
                                          Colors.white.withValues(alpha: 0.85))),
                                ],
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
              const McButton('Cash out · £342.60', icon: 'bank', kind: BtnKind.green),
              const SizedBox(height: 16),
              // Breakdown rows
              _breakdownRow('nav', 'Trip earnings', '£298.20', divider: true),
              _breakdownRow('gift', 'Tips', '£28.40', divider: true),
              _breakdownRow('bolt', 'Bonuses & promotions', '£16.00', divider: false),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('34 trips · 14h 20m online', style: tw(FontWeight.w700, 13, Brand.sub)),
                  GestureDetector(
                    onTap: () => context.push('/payouts'),
                    child: Text('View detail', style: tw(FontWeight.w800, 13, Brand.blue)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
