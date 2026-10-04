import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'mc.dart';

/// The three top-level destinations in the driver tab bar.
enum DriverTab {
  drive('wheel', 'Drive', '/home'),
  earnings('chart', 'Earnings', '/earnings'),
  account('user', 'Account', '/profile');

  const DriverTab(this.icon, this.label, this.route);
  final String icon;
  final String label;
  final String route;
}

/// Drive / Earnings / Account tab bar, for a Scaffold's `bottomNavigationBar`.
///
/// Once copied into each account screen with a fixed 84dp height and 18dp of
/// bottom padding. With Android 15 edge-to-edge a 3-button nav bar (48dp) is
/// drawn over the app, so those labels sat under it and a tap could be
/// swallowed by the system. The bar now pads its bottom by whichever is larger,
/// the old 18dp or the system inset (never both added — the 18dp already is
/// breathing room, so `18 + inset` left a 34dp iPhone home indicator with a
/// 52dp dead strip): the same 66dp band of tabs, lifted clear, with its white
/// still running to the edge. With no inset it is exactly the old 84dp bar.
class DriverTabBar extends StatelessWidget {
  const DriverTabBar({super.key, required this.active});

  final DriverTab active;

  @override
  Widget build(BuildContext context) {
    final bottomPad = math.max(18.0, MediaQuery.paddingOf(context).bottom);
    return Container(
      height: 66 + bottomPad,
      decoration: const BoxDecoration(
        color: Brand.paper,
        border: Border(top: BorderSide(color: Brand.fill)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Row(
        children: [
          for (final tab in DriverTab.values)
            Expanded(
              child: mcTapSemantics(
                label: tab.label,
                enabled: true,
                selected: tab == active,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.go(tab.route),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Ico(tab.icon,
                          size: 24,
                          color: tab == active ? Brand.blue : Brand.faint),
                      const SizedBox(height: 3),
                      Text(tab.label,
                          style: tw(FontWeight.w800, 11,
                              tab == active ? Brand.blue : Brand.faint)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
