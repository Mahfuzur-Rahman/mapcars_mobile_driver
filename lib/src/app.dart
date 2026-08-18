import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/notifications/push_service.dart';
import 'core/notifications/request_alerts.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/drive/providers/dispatch_board_controller.dart';
import 'features/drive/providers/trip_realtime_controller.dart';

class MapcarsDriverApp extends ConsumerStatefulWidget {
  const MapcarsDriverApp({super.key});

  @override
  ConsumerState<MapcarsDriverApp> createState() => _MapcarsDriverAppState();
}

class _MapcarsDriverAppState extends ConsumerState<MapcarsDriverApp>
    with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _fcm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForPushedRequests();
  }

  @override
  void dispose() {
    _fcm?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Android renders **no** notification for an FCM message that arrives while
  /// the app is in the foreground — it is handed to `onMessage` and that is
  /// all. So a driver with the app open but sitting on another screen would be
  /// told nothing by push. Raise the alert ourselves, and re-read the board so
  /// the job is actually there when they tap through.
  ///
  /// The alert de-duplicates by trip id, so this costs nothing when SignalR has
  /// already delivered the same request.
  void _listenForPushedRequests() {
    try {
      _fcm = FirebaseMessaging.onMessage.listen((message) {
        if (message.data['type'] != 'tripAvailable') return;
        final tripId = message.data['tripId'];
        if (tripId == null || tripId.isEmpty) return;

        ref.read(requestAlertsProvider).newRequest(
              tripId: tripId,
              pickup: message.notification?.body,
            );
        ref.read(dispatchBoardProvider.notifier).refreshNow();
      });
    } catch (e) {
      // No Firebase in this build — SignalR and the board's own poll still work.
      if (kDebugMode) debugPrint('[push] foreground listener skipped: $e');
    }
  }

  /// A working driver has the screen off in a cradle for most of a job, and
  /// Android suspends the socket while it is. Coming back re-reads the trip and
  /// re-joins its group, so a cancellation that happened during the drive
  /// surfaces immediately instead of at the driver's next failed action.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(tripRealtimeProvider.notifier).appResumed();
      // Same reasoning for the requests board: anything broadcast while the
      // socket was suspended is gone, so re-read rather than wait for the next
      // request to arrive.
      ref.read(dispatchBoardProvider.notifier).refreshNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Register/unregister this device for push as the auth session comes and
    // goes (token null → signed in → registers; back to null → unregisters).
    ref.listen<String?>(authTokenProvider, (prev, next) {
      final push = ref.read(pushServiceProvider);
      if (next != null && prev == null) {
        push.registerAndListen();
      } else if (next == null && prev != null) {
        push.unregister();
      }
    });

    return MaterialApp.router(
      title: 'Mapcars Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
