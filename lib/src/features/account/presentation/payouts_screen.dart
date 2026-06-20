import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class PayoutsScreen extends StatelessWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const payouts = <(String, String, String)>[
      ('£280.00', 'Mon 9 Jun', 'Paid'),
      ('£312.40', 'Mon 2 Jun', 'Paid'),
      ('£295.10', 'Mon 26 May', 'Paid'),
    ];
    const trips = <(String, String, String)>[
      ('Tower Bridge', 'Today · 4:38 PM', '£9.78'),
      ('Heathrow T5', 'Today · 1:12 PM', '£36.20'),
      ('Borough Mkt', 'Today · 11:05 AM', '£5.40'),
    ];

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Ico('back', size: 24, color: Brand.ink),
                  ),
                  const SizedBox(width: 12),
                  const McTitle('Earnings detail', size: 22),
                ],
              ),
              const SizedBox(height: 16),
              // Next payout card
              McCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Brand.green.withValues(alpha: 0.094),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Ico('bank', size: 22, color: Brand.green)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next payout', style: tw(FontWeight.w900, 15)),
                          Text('Mon 16 Jun · Barclays •••• 8842',
                              style: tw(FontWeight.w600, 12.5, Brand.sub)),
                        ],
                      ),
                    ),
                    Text('£342.60', style: tw(FontWeight.w900, 18, Brand.green)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionLabel('PAYOUT HISTORY'),
              const SizedBox(height: 10),
              for (int i = 0; i < payouts.length; i++) ...[
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
                            Text(payouts[i].$1, style: tw(FontWeight.w900, 15)),
                            Text(payouts[i].$2, style: tw(FontWeight.w600, 12, Brand.sub)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Brand.green.withValues(alpha: 0.094),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(payouts[i].$3,
                            style: tw(FontWeight.w800, 11, Brand.green)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _sectionLabel("TODAY'S TRIPS"),
              const SizedBox(height: 8),
              for (int i = 0; i < trips.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                  decoration: BoxDecoration(
                    border: i < trips.length - 1
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
                            Text(trips[i].$1, style: tw(FontWeight.w800, 14)),
                            Text(trips[i].$2, style: tw(FontWeight.w600, 12, Brand.sub)),
                          ],
                        ),
                      ),
                      Text(trips[i].$3, style: tw(FontWeight.w900, 14, Brand.green)),
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
}
