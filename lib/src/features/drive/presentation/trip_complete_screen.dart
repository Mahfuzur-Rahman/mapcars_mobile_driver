import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class TripCompleteScreen extends StatelessWidget {
  const TripCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Brand.gradGreen,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x594FBF3B),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Ico('check', size: 34, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const McTitle('Trip complete', size: 22),
                  const SizedBox(height: 6),
                  Text('You earned',
                      style: tw(FontWeight.w700, 13.5, Brand.sub)),
                  const SizedBox(height: 4),
                  Text('£9.78',
                      style: tw(FontWeight.w900, 40, Brand.ink, -1)),
                ],
              ),
              const SizedBox(height: 16),
              McCard(
                padding: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _BreakdownRow('Trip fare', '£11.50'),
                    const _BreakdownRow('MAP CARS fee (15%)', '−£1.72'),
                    const _BreakdownRow('Tip', '£0.00'),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Brand.fill,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your earnings',
                            style: tw(FontWeight.w900, 15, Brand.ink)),
                        Text('£9.78',
                            style: tw(FontWeight.w900, 18, Brand.green)),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Brand.fill, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Ico('card', size: 18, color: Brand.sub),
                          const SizedBox(width: 8),
                          Text('Paid by card · added to balance',
                              style: tw(FontWeight.w700, 13, Brand.sub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              McCard(
                padding: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Rate Sarah',
                        style: tw(FontWeight.w900, 14, Brand.ink)),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(
                        5,
                        (i) => const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Ico('starF', size: 30, color: Brand.star),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              McButton(
                'Back online',
                icon: 'nav',
                kind: BtnKind.green,
                onTap: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: tw(FontWeight.w600, 14, Brand.sub)),
            Text(value, style: tw(FontWeight.w700, 14, Brand.ink)),
          ],
        ),
      );
}
