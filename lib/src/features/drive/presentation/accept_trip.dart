import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/dispatch_board_controller.dart';
import '../providers/driver_location_reporting_controller.dart';
import '../providers/trip_realtime_controller.dart';
import '../services/trip_service.dart';

/// Accepts an open request and, if this driver won the first-come race, arms
/// everything an active trip needs before landing them on the pickup leg:
/// the trip id on every location push (so the rider's map tracks them) and the
/// trip's realtime group (so a rider cancellation reaches them).
///
/// Shared by the home screen's request overlay and the `/request` screen so the
/// two can't drift — a request accepted from one has to behave exactly like a
/// request accepted from the other.
Future<void> acceptTripAndGo(
    BuildContext context, WidgetRef ref, Trip trip) async {
  final accepted = await ref.read(dispatchBoardProvider.notifier).accept(trip.id);
  if (!context.mounted) return;

  if (accepted == null) {
    final error = ref.read(dispatchBoardProvider).error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error ?? 'That request is no longer available.'),
      ));
    return;
  }

  ref.read(driverLocationReportingProvider).setActiveTrip(accepted.id);
  unawaited(ref.read(tripRealtimeProvider.notifier).attach(accepted.id));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
      content: Text('Trip accepted — head to the pickup.'),
    ));
  context.go('/nav-pickup', extra: accepted);
}
