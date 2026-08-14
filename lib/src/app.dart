import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MapcarsDriverApp extends ConsumerWidget {
  const MapcarsDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
