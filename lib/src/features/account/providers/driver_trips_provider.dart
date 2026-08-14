import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drive/services/trip_service.dart';

/// The signed-in driver's own trips (`GET /trips/mine`) — shared by the
/// earnings, payouts, and history screens so they don't each fetch it
/// independently.
final driverTripsProvider = FutureProvider.autoDispose<List<Trip>>(
  (ref) => ref.watch(tripServiceProvider).mine(),
);
