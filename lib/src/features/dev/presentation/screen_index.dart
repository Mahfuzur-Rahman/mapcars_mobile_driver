import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../drive/demo_trip.dart';

/// Routes that render a real trip-flow screen and need a [Trip] to show their
/// real map/data instead of falling back to static walkthrough art.
const _routesNeedingDemoTrip = {
  '/request',
  '/nav-pickup',
  '/arrived',
  '/driving',
  '/trip-complete',
  '/chat',
};

/// Prototype helper — jump to any screen. Reached from the splash screen.
class ScreenIndexScreen extends StatelessWidget {
  const ScreenIndexScreen({super.key});

  static const _groups = <String, List<List<String>>>{
    'Onboarding': [
      ['Splash', '/'],
      ['Intro carousel', '/intro'],
      ['Phone + OTP', '/verify'],
      ['Registration', '/registration'],
      ['Document upload', '/documents'],
      ['Under review', '/under-review'],
    ],
    'Driving': [
      ['Home (online + map)', '/home'],
      ['Incoming request', '/request'],
      ['Navigate to pickup', '/nav-pickup'],
      ['Arrived / confirm', '/arrived'],
      ['Chat', '/chat'],
      ['Trip in progress', '/driving'],
      ['Trip complete', '/trip-complete'],
    ],
    'Account': [
      ['Earnings dashboard', '/earnings'],
      ['Payout history', '/payouts'],
      ['Trip history', '/history'],
      ['Profile & vehicle', '/profile'],
      ['Settings', '/settings'],
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      appBar: AppBar(
        backgroundColor: Brand.paper,
        title: const Text('All screens · Driver'),
        titleTextStyle: tw(FontWeight.w900, 18, Brand.ink),
        iconTheme: const IconThemeData(color: Brand.ink),
        actions: [
          Consumer(
            builder: (context, ref, _) => IconButton(
              icon: const Icon(Icons.menu, color: Brand.ink),
              tooltip: 'Open menu',
              onPressed: () => openMenuDrawer(ref),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          for (final entry in _groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(entry.key.toUpperCase(),
                  style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
            ),
            McCard(
              padding: 0,
              child: Column(
                children: [
                  for (int i = 0; i < entry.value.length; i++)
                    InkWell(
                      onTap: () => context.push(
                        entry.value[i][1],
                        extra: _routesNeedingDemoTrip.contains(entry.value[i][1])
                            ? demoTrip
                            : null,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: i < entry.value.length - 1
                              ? const Border(bottom: BorderSide(color: Brand.fill))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.value[i][0], style: tw(FontWeight.w700, 15))),
                            const Ico('chevR', size: 18, color: Brand.faint),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
