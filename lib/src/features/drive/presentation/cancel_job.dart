import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/mc.dart';
import '../providers/active_trip_provider.dart';
import '../providers/driver_location_reporting_controller.dart';
import '../providers/trip_realtime_controller.dart';
import '../services/trip_service.dart';

/// Drops a job the driver has already accepted, any time before they start the
/// trip. `POST /trips/{id}/cancel` accepts either party right up to completion;
/// the driver app deliberately only offers it on the two pre-start screens
/// (`/nav-pickup` and `/arrived`) — once the rider is in the car, the way out
/// is to finish the trip.
///
/// Tears down exactly what [showTripCancelledDialog] does when the *rider*
/// cancels — realtime group, the trip id on location pushes, the cached active
/// trip — so the driver lands back on Home still online, with the board live.
///
/// Shared by [NavPickupScreen] and [ArrivedScreen] so the two can't drift.
/// From the arrived screen it also offers the **no-show** flag: the API only
/// honours it once the driver has actually called `arrive`, and it's what
/// separates "the rider never came out" from a driver-initiated drop in the
/// rider's record.
Future<void> confirmCancelJob(
    BuildContext context, WidgetRef ref, Trip trip) async {
  final reasonController = TextEditingController();
  final canNoShow = trip.status == TripStatus.driverArrived;
  var noShow = false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Cancel this job?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your rider will be told the trip is off and will have to book "
                "again. Cancelling counts towards your cancellation rate.",
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (canNoShow) ...[
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: noShow,
                  onChanged: (v) => setDialogState(() => noShow = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Brand.blue,
                  title: Text("Rider didn't show up",
                      style: tw(FontWeight.w800, 14, Brand.ink)),
                  subtitle: Text('Records this as a no-show against the rider.',
                      style: tw(FontWeight.w600, 12, Brand.sub)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Keep job', style: tw(FontWeight.w700, 14, Brand.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child:
                Text('Cancel job', style: tw(FontWeight.w800, 14, Colors.red)),
          ),
        ],
      ),
    ),
  );

  final reason = reasonController.text.trim();
  reasonController.dispose();
  if (confirmed != true) return;

  // The server pushes this cancellation to the trip's own group, which this
  // driver is in — arm the guard first so their own action doesn't come back
  // at them as the "trip cancelled out from under you" dialog.
  final realtime = ref.read(tripRealtimeProvider.notifier);
  realtime.expectOwnCancellation(trip.id);

  try {
    await ref.read(tripServiceProvider).cancel(
          trip.id,
          reason: reason.isEmpty ? null : reason,
          isNoShow: canNoShow && noShow,
        );
  } catch (e) {
    // The usual loser here is a race the driver can't see: the rider cancelled
    // first, so the trip is already closed. Say what the API said and stay put
    // — the realtime cancellation push moves them on a moment later, which is
    // exactly why the guard has to come back off.
    realtime.forgetOwnCancellation();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(e is ApiException
            ? e.message
            : "Couldn't cancel this job. Please try again."),
      ));
    return;
  }

  await realtime.detach();
  ref.read(driverLocationReportingProvider).setActiveTrip(null);
  ref.invalidate(activeTripProvider);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Job cancelled.')));
  context.go('/home');
}
