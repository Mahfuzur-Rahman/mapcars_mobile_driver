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

  /// Idempotent: a no-op if already attached to this trip.
  Future<void> attach(String tripId) async {
    if (_activeTripId == tripId) return;
    _activeTripId = tripId;

    final token = _ref.read(authTokenProvider);
    if (token == null) return;

    await _rt.connect(token, {
      'tripUpdated': _onTripUpdated,
      'messageReceived': _onMessageReceived,
    });
    await _rt.invoke('JoinTrip', args: [tripId]);
  }

  Future<void> detach() async {
    _activeTripId = null;
    await _rt.disconnect();
    if (mounted) state = const TripRealtimeState();
  }

  void _onTripUpdated(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is! Map) return;
    try {
      final trip = Trip.fromJson(Map<String, dynamic>.from(raw));
      if (trip.id != _activeTripId) return;
      // Every other status is the driver's own action (accept/arrive/start/
      // complete) echoing back — only a cancellation is news to react to.
      final cancelled = trip.status == TripStatus.cancelledByRider ||
          trip.status == TripStatus.cancelledByDriver;
      if (cancelled && mounted) state = TripRealtimeState(cancelledTrip: trip);
    } catch (e) {
      if (kDebugMode) debugPrint('[trip-realtime] bad tripUpdated payload: $e');
    }
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
