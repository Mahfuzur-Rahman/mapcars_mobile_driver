import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On-device alert for the one thing a driver must never miss: a new ride
/// request landing on their board.
///
/// Three delivery paths exist and none of them alone is enough, which is why
/// this class is raised by the app rather than left to the server:
///
///  * **SignalR `tripAvailable`** updates the board, but silently — a driver
///    looking at any other screen, or at their pocket, sees nothing.
///  * **FCM in the foreground** renders *no* notification on Android. The
///    message arrives in `onMessage` and it is the app's job to show something.
///  * **FCM in the background** does render a tray notification, but only once
///    the server's Firebase credentials are actually in place; until then the
///    API falls back to a console stub and the push never leaves the server.
///
/// So the app alerts on whatever it observes first, and [newRequest] is
/// deliberately idempotent per trip so the same job arriving over both SignalR
/// and FCM buzzes the phone once, not twice.
///
/// Every call is best-effort: a failed alert must never disturb driving.
class RequestAlerts {
  static const _channelId = 'mapcars_requests';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Trip ids already announced. A driver who has been online for hours
  /// accumulates a handful of these; they are ~36 bytes each, so this is
  /// bounded in practice by the shift, not by traffic.
  final Set<String> _announced = <String>{};

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));

      // Max importance so Android renders a heads-up banner with sound. A
      // silent tray entry is worthless to someone waiting between jobs — the
      // whole point is to be noticed without the app being open.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Ride requests',
            description: 'A new ride request is available to accept.',
            importance: Importance.max,
          ));
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[requests] init failed: $e');
    }
  }

  /// A new open request is on the board. [tripId] de-duplicates the alert
  /// across delivery channels; [pickup] and [fare] give the driver enough to
  /// decide without unlocking the phone.
  Future<void> newRequest({
    required String tripId,
    String? pickup,
    String? fare,
  }) async {
    if (!_announced.add(tripId)) return; // already announced this job

    final where = (pickup == null || pickup.trim().isEmpty)
        ? 'Tap to see the pickup.'
        : 'Pickup: $pickup';

    await _show(
      // Distinct id per trip so a second request does not replace the banner
      // for the first one still sitting unaccepted.
      id: 9000 + (tripId.hashCode.abs() % 1000),
      title: fare == null ? 'New ride request' : 'New ride request · $fare',
      body: where,
    );
  }

  /// Forget [tripId], so if it somehow comes back on the board it can alert
  /// again. Called when a request is taken or withdrawn.
  void forget(String tripId) => _announced.remove(tripId);

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureReady();
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Ride requests',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            // A request expires the moment another driver takes it, so it is
            // time-critical in Android's sense and should cut through.
            category: AndroidNotificationCategory.call,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      await HapticFeedback.heavyImpact();
    } catch (e) {
      if (kDebugMode) debugPrint('[requests] show failed: $e');
    }
  }
}

final requestAlertsProvider = Provider<RequestAlerts>((ref) => RequestAlerts());
