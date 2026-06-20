import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'mc.dart';

/// One entry in the prototype walk-through order.
class StepRoute {
  const StepRoute(this.path, this.label);
  final String path;
  final String label;
}

/// Wraps every screen with a small floating "‹ n/total · Name ›" bar so you can
/// tap through all screens in order to confirm each one renders. Tapping the
/// label opens the full screen index. Hidden on routes not in [routes].
class ScreenStepper extends StatelessWidget {
  const ScreenStepper({super.key, required this.routes, required this.current, required this.child});
  final List<StepRoute> routes;
  final String current;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = routes.indexWhere((r) => r.path == current);
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (index >= 0)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Bar(routes: routes, index: index),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.routes, required this.index});
  final List<StepRoute> routes;
  final int index;

  @override
  Widget build(BuildContext context) {
    final hasPrev = index > 0;
    final hasNext = index < routes.length - 1;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Brand.ink.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(99),
          boxShadow: Brand.floatShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.chevron_left, hasPrev ? () => context.go(routes[index - 1].path) : null),
            GestureDetector(
              onTap: () => context.push('/screens'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${index + 1}/${routes.length} · ${routes[index].label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
            ),
            _btn(Icons.chevron_right, hasNext ? () => context.go(routes[index + 1].path) : null),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 22, color: onTap == null ? Colors.white24 : Colors.white),
        ),
      );
}
