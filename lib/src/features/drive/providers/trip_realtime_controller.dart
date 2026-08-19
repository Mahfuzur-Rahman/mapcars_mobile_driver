import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/realtime/realtime_service.dart';
import '../models/chat_message.dart';
import '../services/trip_service.dart';
import 'driver_location_reporting_controller.dart';

/// Latest rider/system-cancelled trip pushed over realtime, if any — screens
/// watch this to notice a cancellation that happened out from under them.
class TripRealtimeState {
  const TripRealtimeState({this.cancelledTrip, this.chatMessages = const []});
  final Trip? cancelledTrip;

  /// Chat messages for the active trip — seeded from GET on mount,
  /// appended by messageReceived pushes and local sends.
  final List<ChatMessage> chatMessages;

  TripRealtimeState copyWith({
    Trip? cancelledTrip,
    List<ChatMessage>? chatMessages,
  }) =>
      TripRealtimeState(
        cancelledTrip: cancelledTrip ?? this.cancelledTrip,
        chatMessages: chatMessages ?? this.chatMessages,
      );
}

/// Joins the active trip's SignalR group so a rider (or ops) cancellation
/// reaches the driver immediately, instead of only surfacing once the
/// driver's own next arrive/start/complete call happens to fail against an
/// already-cancelled trip.
///
/// Lives behind a plain [StateNotifierProvider] — like [dispatchBoardProvider]
/// — so it survives the `context.go` navigations between `/nav-pickup` →
/// `/arrived` → `/driving`; nothing but an explicit [detach] call tears it
/// down, same reasoning as [DriverLocationReportingController].
class TripRealtimeController extends StateNotifier<TripRealtimeState> {
  TripRealtimeController(this._ref) : super(const TripRealtimeState());

  final Ref _ref;
  final RealtimeService _rt = RealtimeService();
  String? _activeTripId;

  /// How often the trip is re-read over REST while the socket is down. A driver
  /// who doesn't hear about a cancellation keeps driving to a pickup that isn't
  /// happening, so this is short.
  static const _pollWhenOffline = Duration(seconds: 6);

  /// Heartbeat while the socket is up — "connected" is not proof of
  /// "subscribed", which is the failure this net exists for.
  static const _pollWhenOnline = Duration(seconds: 20);

  Timer? _watchdog;
  bool _connected = false;

  /// The trip the driver is cancelling themselves. The server pushes that
  /// cancellation back to the trip's own group — this driver included — so
  /// without this their own Cancel job would bounce back through [_absorb] as a
  /// "cancelled out from under you" dialog on top of the action they just took.
  /// A successful cancel calls [detach] straight after, which clears it.
  String? _selfCancelledTripId;

  /// Arm the guard above, just before `POST /trips/{id}/cancel`.
  void expectOwnCancellation(String tripId) => _selfCancelledTripId = tripId;

  /// Disarm it when that call failed — the trip is still live, so a real
  /// cancellation arriving later still has to reach the driver.
  void forgetOwnCancellation() => _selfCancelledTripId = null;

  /// Idempotent: a no-op if already attached to this trip.
  Future<void> attach(String tripId) async {
    if (_activeTripId == tripId) return;
    _activeTripId = tripId;
    _startWatchdog();

    final token = _ref.read(authTokenProvider);
    if (token == null) return;

    _rt.onConnectionChange = (connected) {
      _connected = connected;
      if (connected) unawaited(_refreshTrip());
      _startWatchdog();
    };

    await _rt.connect(token, {
      'tripUpdated': _onTripUpdated,
      'messageReceived': _onMessageReceived,
    });
    // joinTrip, not invoke: group membership is per connection id, so a
    // reconnect silently unsubscribes unless the service replays it.
    await _rt.joinTrip(tripId);
  }

  Future<void> detach() async {
    _activeTripId = null;
    _selfCancelledTripId = null;
    _watchdog?.cancel();
    _watchdog = null;
    await _rt.disconnect();
    if (mounted) state = const TripRealtimeState();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    if (_activeTripId == null) {
      _watchdog = null;
      return;
    }
    final every = _connected ? _pollWhenOnline : _pollWhenOffline;
    _watchdog = Timer(every, () {
      _watchdog = null;
      unawaited(_refreshTrip().whenComplete(_startWatchdog));
    });
  }

  /// Re-reads the active trip over REST and folds it through the same handler
  /// the push uses, so a cancellation is noticed either way.
  Future<void> _refreshTrip() async {
    final tripId = _activeTripId;
    if (tripId == null) return;
    try {
      final trip = await _ref.read(tripServiceProvider).get(tripId);
      _absorb(trip);
    } catch (e) {
      if (kDebugMode) debugPrint('[trip-realtime] poll failed: $e');
    }
  }

  /// Call when the app returns to the foreground — a driver's phone spends the
  /// drive with the screen off, and Android suspends the socket while it is.
  Future<void> appResumed() async {
    final tripId = _activeTripId;
    if (tripId == null) return;
    await _refreshTrip();
    final token = _ref.read(authTokenProvider);
    if (token != null) {
      await _rt.connect(token, {
        'tripUpdated': _onTripUpdated,
        'messageReceived': _onMessageReceived,
      });
      await _rt.joinTrip(tripId);
    }
  }

  void _onTripUpdated(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is! Map) return;
    try {
      _absorb(Trip.fromJson(Map<String, dynamic>.from(raw)));
    } catch (e) {
      if (kDebugMode) debugPrint('[trip-realtime] bad tripUpdated payload: $e');
    }
  }

  /// The single place a trip update lands, whether it came over the socket or
  /// out of the REST poll.
  void _absorb(Trip trip) {
    if (trip.id != _activeTripId) return;
    // Every other status is the driver's own action (accept/arrive/start/
    // complete) echoing back — only a cancellation is news to react to.
    final cancelled = trip.status == TripStatus.cancelledByRider ||
        trip.status == TripStatus.cancelledByDriver;
    if (trip.id == _selfCancelledTripId) return; // their own Cancel job, echoed
    if (cancelled && mounted) state = TripRealtimeState(cancelledTrip: trip);
  }

  void _onMessageReceived(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is! Map) return;
    try {
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(raw));
      if (msg.tripId != _activeTripId) return;
      // Deduplicate: the sender's own echo is already appended optimistically
      // by sendMessage — skip it if we see it again from the push.
      final already = state.chatMessages.any((m) => m.id == msg.id);
      if (!already && mounted) {
        state = state.copyWith(
            chatMessages: [...state.chatMessages, msg]);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[trip-realtime] bad messageReceived payload: $e');
    }
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  /// Fetches the full message history for the active trip (called on chat
  /// screen mount). Replaces whatever is in state.
  Future<void> fetchMessages() async {
    final tripId = _activeTripId;
    if (tripId == null) return;
    try {
      final svc = _ref.read(tripServiceProvider);
      final messages = await svc.getMessages(tripId);
      if (mounted) state = state.copyWith(chatMessages: messages);
    } catch (e) {
      if (kDebugMode) debugPrint('[trip-realtime] fetchMessages failed: $e');
    }
  }

  /// Sends a message and appends the server's response (with its real ID)
  /// to state. The realtime push will also arrive, but [_onMessageReceived]
  /// deduplicates by ID so there's no double.
  Future<void> sendMessage(String content) async {
    final tripId = _activeTripId;
    if (tripId == null) return;
    try {
      final svc = _ref.read(tripServiceProvider);
      final msg = await svc.sendMessage(tripId, content: content);
      if (mounted) {
        state = state.copyWith(
            chatMessages: [...state.chatMessages, msg]);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[trip-realtime] sendMessage failed: $e');
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _rt.disconnect();
    super.dispose();
  }
}

final tripRealtimeProvider =
    StateNotifierProvider<TripRealtimeController, TripRealtimeState>(
        (ref) => TripRealtimeController(ref));

/// Blocking dialog shown on any of the three trip screens when the active
/// trip is cancelled out from under the driver. Tears down realtime + location
/// reporting for this trip and sends the driver back to a safe screen.
Future<void> showTripCancelledDialog(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Trip cancelled'),
      content: Text(
        trip.status == TripStatus.cancelledByRider
            ? 'The rider cancelled this trip.'
            : 'This trip was cancelled.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  await ref.read(tripRealtimeProvider.notifier).detach();
  ref.read(driverLocationReportingProvider).setActiveTrip(null);
  if (context.mounted) context.go('/home');
}
