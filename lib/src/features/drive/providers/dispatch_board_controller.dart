import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_service.dart';
import '../services/trip_service.dart';

/// The driver's live requests board: every open trip currently offered to
/// them, plus which one (if any) is mid-accept.
class DispatchBoardState {
  const DispatchBoardState({this.trips = const [], this.busyTripId, this.error});

  final List<Trip> trips;
  final String? busyTripId;
  final String? error;
}

/// Drives the real broadcast dispatch board: seeds it from
/// `GET /trips/available/nearby`, then keeps it current from two SignalR
/// pushes — `tripAvailable` (a new open request reaches this driver) and
/// `tripTaken` (a request this driver was shown is no longer open — someone
/// else accepted it, or it was cancelled before anyone did — drop it from the
/// board). Note this is `tripTaken`, not `tripUpdated`: `tripUpdated` only
/// reaches a trip's own SignalR group, which a driver only joins once *they*
/// are the assigned driver — it would never fire for the other nearby drivers
/// whose boards also need the removal. Accepting is first-come-wins against
/// `POST /trips/{id}/accept`; a 400 means another driver got there first.
/// Started/stopped by the home screen with the online toggle.
class DispatchBoardController extends StateNotifier<DispatchBoardState> {
  DispatchBoardController(this._ref) : super(const DispatchBoardState());

  final Ref _ref;
  final RealtimeService _rt = RealtimeService();
  bool _active = false;

  Future<void> start(double lat, double lng) async {
    if (_active) return;
    _active = true;

    final token = _ref.read(authTokenProvider);
    if (token == null) return;

    await _rt.connect(token, {
      'tripAvailable': _onAvailable,
      'tripTaken': _onTaken,
    });

    try {
      final trips = await _ref
          .read(tripServiceProvider)
          .availableNearby(lat: lat, lng: lng);
      if (_active && mounted) {
        state = DispatchBoardState(trips: trips);
      }
    } catch (_) {
      /* board stays empty; a tripAvailable push may still arrive */
    }
  }

  Future<void> stop() async {
    _active = false;
    await _rt.disconnect();
    if (mounted) state = const DispatchBoardState();
  }

  void _onAvailable(List<Object?>? args) {
    if (!_active || args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is! Map) return;
    try {
      final trip = Trip.fromJson(Map<String, dynamic>.from(raw));
      if (state.trips.any((t) => t.id == trip.id)) return;
      HapticFeedback.heavyImpact();
      if (mounted) {
        state = DispatchBoardState(
          trips: [...state.trips, trip],
          busyTripId: state.busyTripId,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[dispatch] bad tripAvailable payload: $e');
    }
  }

  void _onTaken(List<Object?>? args) {
    if (!_active || args == null || args.isEmpty) return;
    final tripId = args.first?.toString();
    if (tripId == null || tripId.isEmpty || !mounted) return;
    state = DispatchBoardState(
      trips: state.trips.where((t) => t.id != tripId).toList(),
      busyTripId: state.busyTripId,
    );
  }

  /// Brings [tripId] to the front of the board (e.g. the driver tapped its
  /// map pin) without changing what's actually on offer.
  void bringToFront(String tripId) {
    final list = [...state.trips];
    final i = list.indexWhere((t) => t.id == tripId);
    if (i <= 0) return;
    final trip = list.removeAt(i);
    list.insert(0, trip);
    state = DispatchBoardState(trips: list, busyTripId: state.busyTripId);
  }

  /// Locally deprioritizes [tripId] (moves it to the back) so a different
  /// request comes to the front. There's no server-side decline in the
  /// broadcast model — the request stays live for every other driver.
  void ignore(String tripId) {
    final list = [...state.trips];
    final i = list.indexWhere((t) => t.id == tripId);
    if (i < 0) return;
    final trip = list.removeAt(i);
    list.add(trip);
    state = DispatchBoardState(trips: list, busyTripId: state.busyTripId);
  }

  /// Accept [tripId]. Returns the accepted [Trip] on success, or null if
  /// another driver won the race (or the call otherwise failed) — either way
  /// the trip is dropped from the local board.
  Future<Trip?> accept(String tripId) async {
    state = DispatchBoardState(trips: state.trips, busyTripId: tripId);
    try {
      final trip = await _ref.read(tripServiceProvider).accept(tripId);
      state = DispatchBoardState(
        trips: state.trips.where((t) => t.id != tripId).toList(),
      );
      return trip;
    } catch (e) {
      state = DispatchBoardState(
        trips: state.trips.where((t) => t.id != tripId).toList(),
        error: e is ApiException ? e.message : 'That request is no longer available.',
      );
      return null;
    }
  }

  @override
  void dispose() {
    _rt.disconnect();
    super.dispose();
  }
}

final dispatchBoardProvider =
    StateNotifierProvider<DispatchBoardController, DispatchBoardState>(
        (ref) => DispatchBoardController(ref));
