import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Background isolate handler — must be a top-level function. Nothing to do here
/// (the OS renders the notification tray for messages with a `notification`
/// block); it only has to exist so background delivery is wired up.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Registers this install's FCM token with the API and keeps it fresh. Every
/// step is best-effort — push must never break the app if Firebase or
/// notification permission isn't available.
class PushService {
  PushService(this._dio);
  final Dio _dio;

  /// Ask for permission, send the current token, and keep it updated on refresh.
  Future<void> registerAndListen() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
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
