import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'api_exception.dart';

/// Token provider — holds the current JWT.
/// Auth screens write here after a successful login/OTP verification.
final authTokenProvider = StateProvider<String?>((ref) => null);

/// Bumped whenever the API rejects our token (HTTP 401). The auth feature
/// listens to this and tears down the session — keeping core/ independent of
/// features/ (core never imports a feature).
final unauthorizedProvider = StateProvider<int>((ref) => 0);

/// Dio instance wired to the correct API base URL and auth token.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  ));

  // Inject Bearer token on every request
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        // Only react to 401s on authenticated calls — a 401 during login/OTP
        // means "wrong credentials", not an expired session, and there's no
        // token to drop in that case.
        if (e.response?.statusCode == 401 &&
            ref.read(authTokenProvider) != null) {
          ref.read(authTokenProvider.notifier).state = null;
          ref.read(unauthorizedProvider.notifier).state++;
        }
        if (kDebugMode) {
          debugPrint(
            '[API] ${e.requestOptions.method} ${e.requestOptions.path} '
            '→ ${e.response?.statusCode} ${e.message}',
          );
        }
        handler.next(e);
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => debugPrint(o.toString()),
    ));
  }

  return dio;
});

/// Wraps a Dio call and converts [DioException] → [ApiException].
Future<T> apiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiException.fromDioError(e);
  }
}
