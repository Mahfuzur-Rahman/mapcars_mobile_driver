import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';
import '../router/app_router.dart';
import '../../features/drive/providers/dispatch_board_controller.dart';
import '../../features/drive/providers/driver_location_reporting_controller.dart';
import '../../features/drive/providers/trip_realtime_controller.dart';
import '../../features/drive/services/trip_service.dart';
import 'push_tap.dart';

/// Carries out a [PushTap] with the app's own router and controllers. The
/// decision of *where* was already made by [pushTapFor]; this only knows *how*
/// each destination is reached safely.
class PushTapNavigator {
  PushTapNavigator(this._ref);
  final Ref _ref;

  /// The trip screens that listen for a cancellation of the trip they show
  /// (`/chat` is pushed over one of them, which is still listening beneath).
  static const _tripScreens = {'/nav-pickup', '/arrived', '/driving', '/chat'};

  GoRouter get _router => _ref.read(routerProvider);

  /// The top-most leaf location, pushed routes included — `/chat` over
  /// `/driving` reads as `/chat`.
  String? get _here =>
      _router.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation;

  /// Lets a `go` land before a `push` builds on it. `push` stacks onto the
  /// router's *current* configuration, so a push issued before the go has been
  /// applied would stack onto the old stack and silently drop the go.
  static Future<void> _settle() => Future<void>.delayed(Duration.zero);

  Future<bool> open(PushTap tap) async {
    switch (tap) {
      case JustOpenApp():
        return false;

      case OpenRequestsBoard():
        // Re-read first: the job may be gone already, and a stale board is
        // what makes a driver tap Accept on something that no longer exists.
        unawaited(_ref.read(dispatchBoardProvider.notifier).refreshNow());
        if (_here != '/home') _router.go('/home');
        return true;

      case OpenCancelledTrip(:final tripId):
        return _openCancelled(tripId);

      case OpenTripChat(:final tripId):
        return _openChat(tripId);

      case OpenTierAppeal():
        // Profile underneath, so Back from the appeal screen lands where it
        // normally would.
        _router.go('/profile');
        await _settle();
        unawaited(_router.push('/profile/tier'));
        return true;
    }
  }

  /// The driver is already looking at this trip: leave them there and make the
  /// screen hear about it now. Its listener shows the same "Trip cancelled"
  /// dialog a SignalR push would, and that dialog is what tears down realtime +
  /// location reporting and takes them home. Navigating away ourselves would
  /// skip that teardown.
  ///
  /// Anywhere else (including a cold start, where nothing is attached yet),
  /// home is the honest destination: the job is over.
  Future<bool> _openCancelled(String tripId) async {
    final realtime = _ref.read(tripRealtimeProvider.notifier);
    if (realtime.activeTripId == tripId && _tripScreens.contains(_here)) {
      // Already absorbed means the dialog is already up; another emission
      // would stack a second one on it.
      final known = _ref.read(tripRealtimeProvider).cancelledTrip?.id == tripId;
      if (!known) await realtime.recheck();
      return true;
    }
    if (_here != '/home') _router.go('/home');
    return true;
  }

  /// Chat only exists on a live trip, and it sits on top of that trip's own
  /// screen — so fetch the trip, put the driver on the screen for its status
  /// (as the home screen's resume path does), then push the chat over it.
  Future<bool> _openChat(String tripId) async {
    final realtime = _ref.read(tripRealtimeProvider.notifier);
    if (realtime.activeTripId == tripId && _here == '/chat') {
      return true; // already reading it
    }

    final Trip trip;
    try {
      trip = await _ref.read(tripServiceProvider).get(tripId);
    } catch (e) {
      // Offline, or not this driver's trip — opening the app is all we can do.
      if (kDebugMode) debugPrint('[push-tap] chat trip load failed: $e');
      return false;
    }

    final screen = switch (trip.status) {
      TripStatus.driverAssigned => '/nav-pickup',
      TripStatus.driverArrived => '/arrived',
      TripStatus.inProgress => '/driving',
      _ => null,
    };
    // Finished or cancelled: the conversation is closed, and TripGate would
    // show a different (or no) trip. Don't open a dead chat.
    if (screen == null) return false;

    if (realtime.activeTripId != tripId || _here != screen) {
      // Same re-arm as the home screen's resume: the screen is about to receive
      // the trip through `extra`, so TripGate won't arm it. Without this the
      // customer's map freezes and cancellations go unheard. All idempotent.
      final reporting = _ref.read(driverLocationReportingProvider);
      reporting.setActiveTrip(trip.id);
      reporting.start();
      unawaited(realtime.attach(trip.id));
      _router.go(screen, extra: trip);
      await _settle();
    }
    unawaited(_router.push('/chat', extra: trip));
    return true;
  }
}

/// App-wide tap dispatcher: [PushTapDispatcher] holds taps until the splash
/// says the session is ready, then [PushTapNavigator] carries them out.
final pushTapProvider = Provider<PushTapDispatcher>((ref) {
  final navigator = PushTapNavigator(ref);
  return PushTapDispatcher(
    isSignedIn: () => ref.read(authTokenProvider) != null,
    open: navigator.open,
  );
});
