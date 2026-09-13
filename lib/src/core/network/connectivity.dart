import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network interface up.
///
/// **This is a hint, not proof of reachability.** `connectivity_plus` reports
/// the link layer: a phone joined to a Wi-Fi network with no working uplink, or
/// sitting behind a captive portal, still reports connected. So this drives the
/// banner and nothing else — the REST watchdogs in `dispatch_board_controller`
/// and `trip_realtime_controller` stay the real safety net, because they measure
/// what actually matters (did the request come back) rather than what the OS
/// thinks the radio is doing.
///
/// The inverse case is the useful one: when this says *offline* it is almost
/// always right, and that is the moment worth telling the driver about.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  bool up(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  // Seed from the current state so the banner is correct on a cold start
  // instead of waiting for the first change event.
  try {
    yield up(await connectivity.checkConnectivity());
  } catch (_) {
    // A platform that cannot answer is not evidence of being offline.
    yield true;
  }

  yield* connectivity.onConnectivityChanged.map(up);
});

/// [connectivityProvider] as a plain bool, defaulting to **online**.
///
/// Assume connected until proven otherwise: a spurious "You're offline" while
/// the first check is still in flight is worse than a late one, especially on
/// a screen where the driver is waiting for a job to come in.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
        data: (online) => online,
        orElse: () => true,
      );
});
