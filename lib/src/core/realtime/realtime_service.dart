import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../config/env.dart';

/// Thin wrapper over a SignalR connection to the API's TripHub (`/hubs/trip`).
///
/// The JWT is supplied via [HttpConnectionOptions.accessTokenFactory]; SignalR
/// sends it as the `access_token` query param, which the API reads for hub auth
/// (a WebSocket handshake can't carry an Authorization header).
///
/// Two properties matter more than they look, because a rider's whole awareness
/// of their trip used to hang off this one connection:
///
/// * **Groups are re-joined on every reconnect.** A SignalR group membership is
///   scoped to a *connection id*, and a reconnect always mints a new one. So a
///   reconnect silently unsubscribes the client from `trip:{id}` unless it says
///   `JoinTrip` again — and the server has no way to notice. Riders were losing
///   `tripUpdated` (driver arrived, here's your PIN) about a minute into every
///   trip because of exactly this, and nothing in the app could recover it.
/// * **A failed start leaves no wreckage.** `_conn` is only assigned once
///   `start()` has actually succeeded. It used to be assigned first, so a failed
///   connect left a dead connection in place: `connect` early-returned on it
///   forever after, and `invoke` silently no-op'd because the state wasn't
///   `Connected`. One flaky moment at booking time meant no pushes for the whole
///   ride.
///
/// [withAutomaticReconnect] handles brief drops (0/2/10/30s) and then gives up;
/// [_scheduleRetry] takes over from there, so a connection lost for minutes —
/// tunnel, dead spot, backgrounded app — still comes back on its own.
class RealtimeService {
  /// Backoff for our own retries, after SignalR's built-in policy is exhausted.
  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 30),
  ];

  HubConnection? _conn;
  bool _starting = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// Set once [connect] is called and cleared by [disconnect] — the difference
  /// between "we're down and should keep trying" and "we were told to stop".
  bool _wanted = false;

  String? _token;
  Map<String, void Function(List<Object?>? args)> _handlers = const {};

  /// Trip groups this client belongs to, replayed after every reconnect.
  final Set<String> _joinedTrips = {};

  /// Notified on every transition, so callers can widen their REST safety-net
  /// polling while realtime is down and relax it once it's back.
  void Function(bool connected)? onConnectionChange;

  bool _lastReported = false;

  bool get isConnected => _conn?.state == HubConnectionState.Connected;

  /// Connect with [token], registering [handlers] (event name → callback) before
  /// the connection starts so no early push is missed. Safe to call repeatedly:
  /// a no-op while already connected or mid-connect, and a fresh attempt after a
  /// previous failure.
  Future<void> connect(
    String token,
    Map<String, void Function(List<Object?>? args)> handlers,
  ) async {
    _wanted = true;
    _token = token;
    _handlers = handlers;
    if (isConnected || _starting) return;
    await _open();
  }

  /// Join a trip's group and remember it. Prefer this over `invoke('JoinTrip')`:
  /// only what goes through here is restored after a reconnect.
  Future<void> joinTrip(String tripId) async {
    _joinedTrips.add(tripId);
    await invoke('JoinTrip', args: [tripId]);
  }

  Future<void> leaveTrip(String tripId) async {
    _joinedTrips.remove(tripId);
    await invoke('LeaveTrip', args: [tripId]);
  }

  /// Invoke a hub method. Silently ignored when disconnected — a queued invoke
  /// would be worse than none, since the group replay covers the reconnect case.
  Future<void> invoke(String method, {List<Object> args = const []}) async {
    if (!isConnected) return;
    try {
      await _conn!.invoke(method, args: args);
    } catch (e) {
      if (kDebugMode) debugPrint('[realtime] $method failed: $e');
    }
  }

  Future<void> disconnect() async {
    _wanted = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _joinedTrips.clear();

    final conn = _conn;
    _conn = null;
    _report(false);
    if (conn != null) {
      try {
        await conn.stop();
      } catch (_) {
        /* already down */
      }
    }
  }

  // ── internals ──────────────────────────────────────────────────────────────

  Future<void> _open() async {
    final token = _token;
    if (!_wanted || token == null) return;

    _starting = true;
    try {
      final conn = HubConnectionBuilder()
          .withUrl(
            '${Env.apiBaseUrl}/hubs/trip',
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
              // The package default is 2s, which a phone on mobile data loses
              // to routinely on negotiate alone — and a failed negotiate reads
              // as "realtime is unavailable" for the whole trip.
              requestTimeout: 15000,
            ),
          )
          .withAutomaticReconnect()
          .build();

      _handlers.forEach(conn.on);

      conn.onreconnecting(({Exception? error}) => _report(false));
      conn.onreconnected(({String? connectionId}) {
        // New connection id ⇒ no group memberships. Replay them, or this client
        // is connected and deaf.
        _report(true);
        unawaited(_rejoin());
      });
      conn.onclose(({Exception? error}) {
        if (kDebugMode && error != null) {
          debugPrint('[realtime] closed: $error');
        }
        _conn = null;
        _report(false);
        _scheduleRetry();
      });

      await conn.start();

      // Only now is it a usable connection — see the class comment.
      _conn = conn;
      _retryAttempt = 0;
      _report(true);
      await _rejoin();
    } catch (e) {
      if (kDebugMode) debugPrint('[realtime] connect failed: $e');
      _conn = null;
      _report(false);
      _scheduleRetry();
    } finally {
      _starting = false;
    }
  }

  Future<void> _rejoin() async {
    for (final tripId in _joinedTrips.toList()) {
      await invoke('JoinTrip', args: [tripId]);
    }
  }

  void _scheduleRetry() {
    if (!_wanted || _retryTimer != null || _starting) return;
    final delay = _retryDelays[
        _retryAttempt.clamp(0, _retryDelays.length - 1)];
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_wanted && !isConnected) unawaited(_open());
    });
  }

  void _report(bool connected) {
    if (connected == _lastReported) return;
    _lastReported = connected;
    onConnectionChange?.call(connected);
  }
}
