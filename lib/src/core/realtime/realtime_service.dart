import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../config/env.dart';

/// Thin wrapper over a SignalR connection to the API's TripHub (`/hubs/trip`).
///
/// The JWT is supplied via [HttpConnectionOptions.accessTokenFactory]; SignalR
/// sends it as the `access_token` query param, which the API reads for hub auth
/// (a WebSocket handshake can't carry an Authorization header). Auto-reconnects.
class RealtimeService {
  HubConnection? _conn;

  bool get isConnected => _conn?.state == HubConnectionState.Connected;

  /// Connect with [token], registering [handlers] (event name → callback) before
  /// the connection starts so no early push is missed. No-op if already connected.
  Future<void> connect(
    String token,
    Map<String, void Function(List<Object?>? args)> handlers,
  ) async {
    if (_conn != null) return;

    final conn = HubConnectionBuilder()
        .withUrl(
          '${Env.apiBaseUrl}/hubs/trip',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    handlers.forEach(conn.on);
    _conn = conn;

    try {
      await conn.start();
    } catch (e) {
      if (kDebugMode) debugPrint('[realtime] connect failed: $e');
    }
  }

  /// Invoke a hub method (e.g. `JoinTrip`). Silently ignored when disconnected.
  Future<void> invoke(String method, {List<Object> args = const []}) async {
    if (isConnected) await _conn!.invoke(method, args: args);
  }

  Future<void> disconnect() async {
    final conn = _conn;
    _conn = null;
    if (conn != null) {
      try {
        await conn.stop();
      } catch (_) {
        /* already down */
      }
    }
  }
}
