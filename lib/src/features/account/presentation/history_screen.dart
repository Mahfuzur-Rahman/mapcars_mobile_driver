import 'package:flutter/material.dart';

import '../../../core/widgets/mc.dart';

class DriverHistoryScreen extends StatelessWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const trips = <(String, String, String, int)>[
      ('Tower Bridge, SE1', 'Today · 4:38 PM', '£9.78', 5),
      ('Heathrow Terminal 5', 'Today · 1:12 PM', '£36.20', 5),
      ('Borough Market', 'Today · 11:05 AM', '£5.40', 4),
      ('Shoreditch High St', 'Yesterday · 10:48 PM', '£12.30', 5),
    ];

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: McTitle('Trip history', size: 26),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < trips.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                McCard(
                  padding: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Brand.fill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Ico('nav', size: 22, color: Brand.sub)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Text(trips[i].$1, style: tw(FontWeight.w900, 15))),
                                const SizedBox(width: 8),
                                Text(trips[i].$3, style: tw(FontWeight.w900, 15, Brand.green)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                    child: Text(trips[i].$2,
                                        style: tw(FontWeight.w600, 12.5, Brand.sub))),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Ico('starF', size: 13, color: Brand.star),
                                    const SizedBox(width: 3),
                                    Text('${trips[i].$4}.0',
                                        style: tw(FontWeight.w800, 12, Brand.sub)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
