import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../permissions/permission_gate.dart';

/// Background isolate handler — must be a top-level function. Nothing to do here
/// (the OS renders the notification tray for messages with a `notification`
/// block); it only has to exist so background delivery is wired up.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Android channel the API names on every push (`FcmPushSender`). Created up
/// front: Android silently drops a channel id it has never heard of back to the
/// default one, which has no heads-up banner. Max importance gives a banner and
/// sound even while the app is closed.
const pushChannelId = 'mapcars_push';

Future<void> _ensurePushChannel() async {
  try {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          pushChannelId,
          'Messages & trip updates',
          description: 'Chat messages and trip updates while the app is closed.',
          importance: Importance.max,
        ));
  } catch (e) {
    if (kDebugMode) debugPrint('[push] channel failed: $e');
  }
}

/// Registers this install's FCM token with the API and keeps it fresh. Every
/// step is best-effort — push must never break the app if Firebase or
/// notification permission isn't available.
class PushService {
  PushService(this._dio);
  final Dio _dio;

  /// Ask for permission, send the current token, and keep it updated on refresh.
  Future<void> registerAndListen() async {
    try {
      await _ensurePushChannel();
      final messaging = FirebaseMessaging.instance;
      // Queued: this prompt used to race the first map's location prompt on
      // a fresh install, and Android drops whichever request loses.
      await PermissionGate.request(messaging.requestPermission);
      final token = await messaging.getToken();
      if (token != null) await _sendToken(token);
      messaging.onTokenRefresh.listen(_sendToken);
    } catch (e) {
      if (kDebugMode) debugPrint('[push] register failed: $e');
    }
  }

  Future<void> _sendToken(String token) async {
    try {
      await _dio.post('/api/v1/devices/register',
          data: {'token': token, 'platform': 'android'});
    } catch (e) {
      if (kDebugMode) debugPrint('[push] token register failed: $e');
    }
  }

  /// Drop this device's token server-side (on logout).
  Future<void> unregister() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _dio.delete('/api/v1/devices/${Uri.encodeComponent(token)}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[push] unregister failed: $e');
    }
  }
}

final pushServiceProvider =
    Provider<PushService>((ref) => PushService(ref.watch(dioProvider)));
