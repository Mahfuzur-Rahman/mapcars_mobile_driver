import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/trip_service.dart';

/// The statuses that mean "the driver is working this trip right now".
const _liveStatuses = {
  TripStatus.driverAssigned,
  TripStatus.driverArrived,
  TripStatus.inProgress,
};

/// The driver's current job as the API sees it — null when they have none.
///
/// Trip screens normally receive their [Trip] through go_router's `extra`.
/// This is the answer for every path that can't carry one: the menu / screen
/// index jumping straight to `/driving`, a notification tap, a hot restart, a
/// deep link. Those used to fall back to a hard-coded demo trip ("Sarah M.",
/// Canary Wharf → Tower Bridge, £11.50) that was indistinguishable from a real
/// job — now they either show the driver's actual trip or say there isn't one.
///
/// `GET /trips/mine` is a list view: it omits the rider details and the meet-up
/// PIN, so the winner is re-fetched in full through `GET /trips/{id}` — the same
/// two-step the home screen's resume path does.
final activeTripProvider = FutureProvider.autoDispose<Trip?>((ref) async {
  final trips = ref.watch(tripServiceProvider);
  try {
    final direct = await trips.getActive();
    if (direct != null && _liveStatuses.contains(direct.status)) {
      return direct;
    }
  } catch (_) {}

  final mine = await trips.mine();
  final live = mine.where((t) => _liveStatuses.contains(t.status)).toList();
  if (live.isEmpty) return null;

  final newest =
      live.reduce((a, b) => a.createdAtUtc.isAfter(b.createdAtUtc) ? a : b);
  return trips.get(newest.id);
});

/// The driver's most recently completed trip — what `/trip-complete` shows when
/// it wasn't reached by completing a trip in this session.
final lastCompletedTripProvider = FutureProvider.autoDispose<Trip?>((ref) async {
  final trips = ref.watch(tripServiceProvider);
  final mine = await trips.mine();
  final done = mine.where((t) => t.status == TripStatus.completed).toList();
  if (done.isEmpty) return null;

  DateTime finishedAt(Trip t) => t.completedAtUtc ?? t.createdAtUtc;
  final newest =
      done.reduce((a, b) => finishedAt(a).isAfter(finishedAt(b)) ? a : b);
  return trips.get(newest.id);
});
