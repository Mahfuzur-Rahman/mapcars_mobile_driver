import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class ProfileVehicleScreen extends StatelessWidget {
  const ProfileVehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const stats = <(String, String)>[
      ('1,284', 'Trips'),
      ('96%', 'Acceptance'),
      ('4.92', 'Rating'),
    ];
    const docs = <(String, String)>[
      ('PHV licence', 'Valid'),
      ('Insurance', 'Exp 03/27'),
      ('MOT', 'Valid'),
    ];

    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _DriverTabBar(active: 'account'),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McTitle('Profile', size: 26),
              const SizedBox(height: 18),
              // Profile row
              Row(
                children: [
                  const McAvatar(size: 68, color: Brand.blue),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('James Kowalski', style: tw(FontWeight.w900, 19)),
                        Row(
                          children: [
                            const Ico('starF', size: 15, color: Brand.star),
                            const SizedBox(width: 5),
                            Text('4.92 · Since 2023', style: tw(FontWeight.w700, 13.5, Brand.sub)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Ico('edit', size: 20, color: Brand.sub),
                ],
              ),
              const SizedBox(height: 16),
              // Stat cards
              Row(
                children: [
                  for (int i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: McCard(
                        padding: 12,
                        child: Column(
                          children: [
                            Text(stats[i].$1, style: tw(FontWeight.w900, 18)),
                            Text(stats[i].$2, style: tw(FontWeight.w700, 11, Brand.sub)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Text('VEHICLE', style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
              const SizedBox(height: 10),
              McCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Brand.fill,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Center(child: Ico('car', size: 28, color: Brand.blue)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Toyota Prius', style: tw(FontWeight.w900, 16)),
                              Text('Silver · 2021 · Economy',
                                  style: tw(FontWeight.w600, 12.5, Brand.sub)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Brand.fill,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('LB12 KXR', style: tw(FontWeight.w900, 14, Brand.ink, 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final (label, value) in docs)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Brand.fill)),
                        ),
                        child: Row(
                          children: [
                            const Ico('check', size: 16, color: Brand.green),
                            const SizedBox(width: 10),
                            Expanded(child: Text(label, style: tw(FontWeight.w700, 13.5))),
                            Text(value, style: tw(FontWeight.w800, 12.5, Brand.sub)),
                          ],
                        ),
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
