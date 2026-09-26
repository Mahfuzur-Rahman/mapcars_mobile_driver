import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/mc.dart';
import '../../services/trip_service.dart';

/// What the driver has to do about money at drop-off, shown on the driving
/// screen before they tap Complete.
///
/// * **Cash** — collect the fare (+ tip) in person; no card charge happens.
/// * **Card** — the platform charges the customer and pays the driver whatever
///   happens to that charge, so there is nothing to collect. This used to show
///   nothing at all, which left a driver on a card job wondering whether they
///   were meant to ask for money. Never mention a card failure here: the API
///   hides declines from drivers precisely because they are not the driver's
///   concern.
/// * Anything else (an API newer than this build) — say nothing rather than
///   guess, and never prompt to collect.
class DropOffPaymentBanner extends StatelessWidget {
  const DropOffPaymentBanner({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    if (trip.isCash) {
      return _Banner(
        icon: 'cash',
        tint: Brand.green,
        label: 'Collect from customer in cash',
        trailing: formatGbp((trip.cashDue * 100).round()),
      );
    }
    if (trip.isCard) {
      return const _Banner(
        icon: 'card',
        tint: Brand.blue,
        label: 'Paid by card — nothing to collect',
      );
    }
    return const SizedBox.shrink();
  }
}

/// The trip-complete summary's one-line payment note, or null when the method
/// isn't one this build knows.
String? completedPaymentLine(Trip trip) {
  if (trip.isCash) {
    return 'Collected ${formatGbp((trip.cashDue * 100).round())} in cash';
  }
  if (trip.isCard) return 'Paid by card · nothing to collect';
  return null;
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.tint,
    required this.label,
    this.trailing,
  });

  final String icon;
  final Color tint;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Ico(icon, size: 20, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: tw(FontWeight.w700, 13, Brand.ink)),
          ),
          if (trailing != null)
            Text(trailing!, style: tw(FontWeight.w900, 16, tint)),
        ],
      ),
    );
  }
}
