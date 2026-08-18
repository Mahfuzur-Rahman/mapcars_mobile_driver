import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/drive/providers/trip_realtime_controller.dart';

class MapcarsDriverApp extends ConsumerStatefulWidget {
  const MapcarsDriverApp({super.key});

  @override
  ConsumerState<MapcarsDriverApp> createState() => _MapcarsDriverAppState();
}

class _MapcarsDriverAppState extends ConsumerState<MapcarsDriverApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A working driver has the screen off in a cradle for most of a job, and
  /// Android suspends the socket while it is. Coming back re-reads the trip and
  /// re-joins its group, so a cancellation that happened during the drive
  /// surfaces immediately instead of at the driver's next failed action.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(tripRealtimeProvider.notifier).appResumed();
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
