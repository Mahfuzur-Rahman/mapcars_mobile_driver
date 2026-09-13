import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/server_clock.dart';

/// One beat for the whole app.
///
/// Every countdown on screen watches this rather than owning a `Timer`, for two
/// reasons: a board showing five requests would otherwise run five timers, and —
/// more visibly — they would each tick on their own phase, so cards sitting side
/// by side would flip their seconds at different moments and read as broken.
///
/// `autoDispose` stops the stream whenever nothing is counting down, which is
/// most of the time.
final secondTickerProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream<int>.periodic(const Duration(seconds: 1), (tick) => tick),
);

/// `m:ss`, floored — 0:00 means the deadline has passed.
String formatCountdown(Duration left) {
  final total = left.isNegative ? 0 : left.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Rebuilds once a second with the time left until [deadline], measured on the
/// server's clock (see [ServerClock]).
///
/// Takes a [builder] rather than rendering a fixed style: the rider's search
/// screen and the driver's request card want very different treatments of the
/// same number, and forcing one look would have each of them re-implementing
/// the ticking instead.
class ExpiryCountdown extends ConsumerWidget {
  const ExpiryCountdown({
    super.key,
    required this.deadline,
    required this.builder,
  });

  /// The server-supplied deadline. Null renders [Duration.zero], so a trip that
  /// predates this field shows an elapsed clock rather than crashing.
  final DateTime? deadline;

  final Widget Function(BuildContext context, Duration left) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(secondTickerProvider);
    return builder(context, ServerClock.remainingUntil(deadline));
  }
}
