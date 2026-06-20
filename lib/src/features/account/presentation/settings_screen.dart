import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class DriverSettingsScreen extends StatelessWidget {
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<(String, String)>)>[
      ('Account', [
        ('user', 'Personal info'),
        ('bank', 'Payout method'),
        ('doc', 'Documents'),
      ]),
      ('Driving', [
        ('nav', 'Navigation app'),
        ('bell', 'Sound & alerts'),
        ('globe', 'Language'),
      ]),
      ('Support', [
        ('shield', 'Safety toolkit'),
        ('msg', 'Help centre'),
      ]),
    ];

    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _DriverTabBar(active: 'account'),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: McTitle('Settings', size: 26),
              ),
              const SizedBox(height: 16),
              for (final (label, rows) in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(label, style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
                ),
                const SizedBox(height: 8),
                McCard(
                  padding: 0,
                  child: Column(
                    children: [
                      for (int i = 0; i < rows.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: i < rows.length - 1
                                ? const Border(bottom: BorderSide(color: Brand.fill))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Ico(rows[i].$1, size: 20, color: Brand.sub),
                              const SizedBox(width: 14),
                              Expanded(child: Text(rows[i].$2, style: tw(FontWeight.w700, 15))),
                              const Ico('chevR', size: 18, color: Brand.faint),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              const SizedBox(height: 6),
              Center(child: Text('Log out', style: tw(FontWeight.w800, 14, Brand.blue))),
              const SizedBox(height: 8),
              Center(
                child: Text('MAP CARS Driver · v1.0.0',
                    style: tw(FontWeight.w600, 12, Brand.faint)),
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
