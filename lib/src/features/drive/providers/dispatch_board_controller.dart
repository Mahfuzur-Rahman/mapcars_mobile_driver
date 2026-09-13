import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/notifications/request_alerts.dart';
import '../../../core/realtime/realtime_service.dart';
import '../services/trip_service.dart';

/// The driver's live requests board: every open trip currently offered to
/// them, plus which one (if any) is mid-accept.
class DispatchBoardState {
  const DispatchBoardState({
    this.trips = const [],
    this.busyTripId,
    this.error,
    this.expiredIds = const {},
  });

  final List<Trip> trips;
  final String? busyTripId;
  final String? error;

  /// Requests that have run out of time and are showing their "Expired" state
  /// before being removed. Held here rather than dropped immediately so a driver
  /// reaching for Accept is told what happened instead of watching the card
  /// disappear and the next one jump up under their thumb.
  final Set<String> expiredIds;

  bool isExpired(String tripId) => expiredIds.contains(tripId);

  /// `busyTripId` and `error` are nullable and meaningful when null, so they
  /// take explicit `clear` flags rather than the usual "null means keep".
  DispatchBoardState copyWith({
    List<Trip>? trips,
    String? busyTripId,
    bool clearBusy = false,
    String? error,
    bool clearError = false,
    Set<String>? expiredIds,
  }) =>
      DispatchBoardState(
        trips: trips ?? this.trips,
        busyTripId: clearBusy ? null : (busyTripId ?? this.busyTripId),
        error: clearError ? null : (error ?? this.error),
        expiredIds: expiredIds ?? this.expiredIds,
      );
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
///
/// **A push is never assumed to arrive.** `tripAvailable` only lands if the
/// socket happens to be up at that instant, and a request missed that way used
/// to stay invisible until the driver toggled offline and back on — there was no
/// re-read anywhere, despite the API side commenting that "drivers also poll the
/// board". [_startWatchdog] is that poll: it re-reads
/// `GET /trips/available/nearby` on a timer — fast while the socket is down,
/// slower while it is up, because "connected" is not the same as "subscribed".
/// Anything it finds that the board has not seen alerts exactly like a live push
/// would.
class DispatchBoardController extends StateNotifier<DispatchBoardState> {
  DispatchBoardController(this._ref) : super(const DispatchBoardState());

  /// How often the board is re-read while the socket is down. Requests are
  /// first-come-wins, so a stale board costs the driver real work.
  static const _pollWhenOffline = Duration(seconds: 10);

  /// Heartbeat while the socket is up — insurance against a connection that is
  /// "connected" but no longer in this driver's group.
  static const _pollWhenOnline = Duration(seconds: 30);

  /// How long an expired card stays visible, greyed out, before it is removed.
  static const _expiredLinger = Duration(seconds: 3);

  final Ref _ref;
  final RealtimeService _rt = RealtimeService();

  /// Requests this driver has waved away with Ignore. Kept for the shift so the
  /// poll in [_refresh] and a re-sent `tripAvailable` can't put a job the driver
  /// already turned down back in front of them. Memory only — a request lives
  /// minutes, and [stop] clears it so going offline and back on is a clean slate.
  final Set<String> _ignored = <String>{};

  bool _active = false;
  bool _connected = false;
  Timer? _watchdog;

  /// Trip id → the timer that will drop its expired card. Keyed so a second
  /// signal for the same request (the push and the local countdown both firing)
  /// doesn't restart the linger or double-remove.
  final Map<String, Timer> _expiring = <String, Timer>{};
  double? _lat;
  double? _lng;

  RequestAlerts get _alerts => _ref.read(requestAlertsProvider);

  Future<void> start(double lat, double lng) async {
    if (_active) return;
    _active = true;
    _lat = lat;
    _lng = lng;

    final token = _ref.read(authTokenProvider);
    if (token == null) return;

    // A reconnect mints a new connection id and the server re-adds the driver
    // to their group in OnConnectedAsync — but anything broadcast while the
    // socket was down is simply gone, so every reconnect re-reads the board.
    _rt.onConnectionChange = (connected) {
      _connected = connected;
      if (connected) unawaited(_refresh());
      _startWatchdog();
    };

    await _rt.connect(token, {
      'tripAvailable': _onAvailable,
      'tripTaken': _onTaken,
      'tripExpired': _onExpired,
    });

    await _refresh();
    _startWatchdog();
  }

  /// Keeps the board relevant for a driver who has moved since going online.
  void updatePosition(double lat, double lng) {
    _lat = lat;
    _lng = lng;
  }

  /// Re-read the board right now — used when the app returns to the foreground
  /// and when an FCM request notification arrives while it is open.
  Future<void> refreshNow() => _refresh();

  Future<void> stop() async {
    _active = false;
    _ignored.clear();
    _watchdog?.cancel();
    _watchdog = null;
    for (final timer in _expiring.values) {
      timer.cancel();
    }
    _expiring.clear();
    _rt.onConnectionChange = null;
    await _rt.disconnect();
    if (mounted) state = const DispatchBoardState();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    if (!_active) {
      _watchdog = null;
      return;
    }
    _watchdog = Timer.periodic(
      _connected ? _pollWhenOnline : _pollWhenOffline,
      (_) => unawaited(_refresh()),
    );
  }

  /// Re-reads the open board and merges it in, announcing anything new. This is
  /// what covers a missed push, a resumed app, and a driver who was in a dead
  /// spot when the request went out.
  Future<void> _refresh() async {
    if (!_active) return;
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) return;

    List<Trip> fresh;
    try {
      fresh = await _ref
          .read(tripServiceProvider)
          .availableNearby(lat: lat, lng: lng);
    } catch (_) {
      return; // transient — the next tick tries again
    }
    if (!_active || !mounted) return;

    // An ignored job is still open on the server and still on every other
    // driver's board — it's just no longer on this one.
    fresh = fresh.where((t) => !_ignored.contains(t.id)).toList();

    // Preserve the driver's own ordering (bringToFront / ignore) for jobs still
    // on offer, then append whatever is genuinely new.
    //
    // A card mid-expiry is kept even though the server has stopped listing it —
    // that is the whole point of the grey-out, and a poll landing inside those
    // three seconds would otherwise snatch it away exactly as before.
    final freshById = {for (final t in fresh) t.id: t};
    final kept = <Trip>[
      for (final t in state.trips)
        if (freshById.containsKey(t.id))
          freshById[t.id]!
        else if (state.isExpired(t.id))
          t
    ];
    final keptIds = kept.map((t) => t.id).toSet();
    final added = fresh.where((t) => !keptIds.contains(t.id)).toList();

    // Anything that dropped off may alert again if it ever comes back.
    for (final t in state.trips) {
      if (!freshById.containsKey(t.id)) _alerts.forget(t.id);
    }

    state = DispatchBoardState(
      trips: [...kept, ...added],
      busyTripId: state.busyTripId,
      expiredIds: state.expiredIds,
    );
    for (final trip in added) {
      unawaited(_announce(trip));
    }
  }

  /// Buzz + banner for a new job. [RequestAlerts.newRequest] de-duplicates by
  /// trip id, so the same request arriving over SignalR *and* the poll (or FCM)
  /// alerts once, not three times.
  Future<void> _announce(Trip trip) => _alerts.newRequest(
        tripId: trip.id,
        pickup: trip.pickupAddress,
        fare: trip.fareAmount == null
            ? null
            : '£${trip.fareAmount!.toStringAsFixed(2)}',
      );

  void _onAvailable(List<Object?>? args) {
    if (!_active || args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is! Map) return;
    try {
      final trip = Trip.fromJson(Map<String, dynamic>.from(raw));
      if (_ignored.contains(trip.id)) return;

      // A customer who extends puts their request back on the board, and it may
      // still be sitting here greyed out from the window that just lapsed.
      // Revive that card with the new deadline instead of dropping the offer as
      // a duplicate, which would leave the driver looking at "Expired" for a job
      // that is live again.
      if (state.isExpired(trip.id)) {
        _expiring.remove(trip.id)?.cancel();
        if (mounted) {
          state = state.copyWith(
            trips: [
              for (final t in state.trips) if (t.id == trip.id) trip else t
            ],
            expiredIds: state.expiredIds.difference({trip.id}),
          );
        }
        return;
      }

      if (state.trips.any((t) => t.id == trip.id)) return;
      unawaited(_announce(trip));
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
    _alerts.forget(tripId);
    state = DispatchBoardState(
      trips: state.trips.where((t) => t.id != tripId).toList(),
      busyTripId: state.busyTripId,
      expiredIds: state.expiredIds.difference({tripId}),
    );
  }

  void _onExpired(List<Object?>? args) {
    if (!_active || args == null || args.isEmpty) return;
    final tripId = args.first?.toString();
    if (tripId == null || tripId.isEmpty) return;
    markExpired(tripId);
  }

  /// Marks a request expired, then takes it off the board a beat later.
  ///
  /// Called both by the server's `tripExpired` push and by the card's own
  /// countdown reaching zero — the local path is what covers a dead socket or an
  /// app that was backgrounded through the event. It only changes what is drawn:
  /// whether an accept succeeds is decided by the API on its own clock, so being
  /// early or late here costs a card's appearance, never a job.
  void markExpired(String tripId) {
    if (!mounted || _expiring.containsKey(tripId)) return;
    if (!state.trips.any((t) => t.id == tripId)) return;

    _alerts.forget(tripId);
    state = DispatchBoardState(
      trips: state.trips,
      busyTripId: state.busyTripId,
      expiredIds: {...state.expiredIds, tripId},
    );

    _expiring[tripId] = Timer(_expiredLinger, () {
      _expiring.remove(tripId);
      if (!mounted) return;
      state = DispatchBoardState(
        trips: state.trips.where((t) => t.id != tripId).toList(),
        busyTripId: state.busyTripId,
        expiredIds: state.expiredIds.difference({tripId}),
      );
    });
  }

  /// Brings [tripId] to the front of the board (e.g. the driver tapped its
  /// map pin) without changing what's actually on offer.
  void bringToFront(String tripId) {
    final list = [...state.trips];
    final i = list.indexWhere((t) => t.id == tripId);
    if (i <= 0) return;
    final trip = list.removeAt(i);
    list.insert(0, trip);
    state = state.copyWith(trips: list);
  }

  /// Waves [tripId] away for the rest of this shift: off the board now, and
  /// filtered out of the poll and the `tripAvailable` push so it can't come
  /// back. It used to only move the request to the *back* of the list, which
  /// meant a driver who turned a job down met it again the moment the board
  /// emptied. There's still no server-side decline in the broadcast model —
  /// the request stays live for every other driver.
  void ignore(String tripId) {
    _ignored.add(tripId);
    if (!state.trips.any((t) => t.id == tripId)) return;
    state = state.copyWith(
      trips: state.trips.where((t) => t.id != tripId).toList(),
      expiredIds: state.expiredIds.difference({tripId}),
    );
  }

  /// Whether the driver has already waved [tripId] away — for the one-shot
  /// board on `/request`, which fetches outside this controller's state.
  bool isIgnored(String tripId) => _ignored.contains(tripId);

  /// Accept [tripId]. Returns the accepted [Trip] on success, or null if
  /// another driver won the race (or the call otherwise failed) — either way
  /// the trip is dropped from the local board.
  Future<Trip?> accept(String tripId) async {
    state = state.copyWith(busyTripId: tripId, clearError: true);
    try {
      final trip = await _ref.read(tripServiceProvider).accept(tripId);
      state = state.copyWith(
        trips: state.trips.where((t) => t.id != tripId).toList(),
        clearBusy: true,
        expiredIds: state.expiredIds.difference({tripId}),
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
    _watchdog?.cancel();
    _rt.onConnectionChange = null;
    _rt.disconnect();
    super.dispose();
  }
}

final dispatchBoardProvider =
    StateNotifierProvider<DispatchBoardController, DispatchBoardState>(
        (ref) => DispatchBoardController(ref));
