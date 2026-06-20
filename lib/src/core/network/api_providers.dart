import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

export 'api_client.dart'
    show authTokenProvider, unauthorizedProvider, dioProvider, apiCall;

/// Quick API health check — used by dev tools / splash.
final pingProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get<Map<String, dynamic>>('/api/v1/ping');
  return res.data ?? {};
});
