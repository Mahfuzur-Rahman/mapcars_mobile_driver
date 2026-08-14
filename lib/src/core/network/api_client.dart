import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'api_exception.dart';

/// Token provider — holds the current JWT.
/// Auth screens write here after a successful login/OTP verification.
final authTokenProvider = StateProvider<String?>((ref) => null);

/// The long-lived refresh token. Unlike the JWT above this one survives the
/// access token's expiry, and is what [SessionRefresher] trades in for a new
/// JWT — the reason a signed-in user stays signed in instead of being bounced
/// to the login screen every time the hour is up.
final refreshTokenProvider = StateProvider<String?>((ref) => null);

/// Bumped whenever the API rejects our token (HTTP 401) **and** the session
/// could not be renewed. The auth feature listens to this and tears the session
/// down — keeping core/ independent of features/ (core never imports a feature).
final unauthorizedProvider = StateProvider<int>((ref) => 0);

/// Set whenever a silent refresh succeeds. The auth feature listens, folds the
/// new credentials into its state and re-persists them. Same one-way signalling
/// as [unauthorizedProvider]: core announces, the feature reacts.
final sessionRenewedProvider = StateProvider<RenewedSession?>((ref) => null);

/// Credentials handed back by `POST /api/v1/auth/refresh`.
class RenewedSession {
  const RenewedSession({
    required this.token,
    required this.refreshToken,
    required this.expiresInMinutes,
  });

  final String token;

  /// The API rotates on every refresh, so this is a *different* token from the
  /// one that was sent. Storing it is mandatory — presenting the old one again
  /// reads as a stolen-token replay and kills every session for the account.
  final String refreshToken;

  final int expiresInMinutes;
}

/// Exchanges the stored refresh token for a fresh access token.
class SessionRefresher {
  SessionRefresher(this._ref);

  final Ref _ref;

  /// The refresh currently in flight, if any.
  ///
  /// Coalescing matters more than it looks. Several requests can 401 at the same
  /// instant (the home screen alone fires a few), and because the API *rotates*
  /// the refresh token on use, a second concurrent call would present a token
  /// that was just retired — which the server reads as a replay and answers by
  /// revoking every session the user has. Parallel callers therefore all await
  /// this one future.
  Future<bool>? _inFlight;

  Future<bool> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _run();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<bool> _run() async {
    final refreshToken = _ref.read(refreshTokenProvider);
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      // A bare Dio on purpose: the app's own instance carries the interceptor
      // below, so refreshing through it would recurse on failure.
      final dio = Dio(BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      ));

      final res = await dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final data = res.data;
      if (data == null || data['token'] is! String) return false;

      final renewed = RenewedSession(
        token: data['token'] as String,
        refreshToken: data['refreshToken'] as String? ?? refreshToken,
        expiresInMinutes: data['expiresInMinutes'] as int? ?? 60,
      );

      _ref.read(authTokenProvider.notifier).state = renewed.token;
      _ref.read(refreshTokenProvider.notifier).state = renewed.refreshToken;
      _ref.read(sessionRenewedProvider.notifier).state = renewed;
      return true;
    } catch (e) {
      // A 401 here means the refresh token is genuinely dead (expired, revoked,
      // or replayed) — the user really does have to sign in again. Anything else
      // is usually the network, and the caller will simply try again later.
      if (kDebugMode) debugPrint('[API] refresh failed: $e');
      return false;
    }
  }
}

final sessionRefresherProvider =
    Provider<SessionRefresher>((ref) => SessionRefresher(ref));

/// Marks a request that has already been retried after a refresh, so a second
/// 401 on the same request falls through to sign-out instead of looping.
const _retriedKey = '__mapcars_retried';

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
      onError: (e, handler) async {
        if (kDebugMode) {
          debugPrint(
            '[API] ${e.requestOptions.method} ${e.requestOptions.path} '
            '→ ${e.response?.statusCode} ${e.message}',
          );
        }

        // Only react to 401s on authenticated calls — a 401 during login/OTP
        // means "wrong credentials", not an expired session, and there's no
        // token to drop in that case.
        final path = e.requestOptions.path;
        final isSessionCall =
            path.contains('/auth/refresh') || path.contains('/auth/logout');

        if (e.response?.statusCode != 401 ||
            isSessionCall ||
            ref.read(authTokenProvider) == null) {
          return handler.next(e);
        }

        // The access token has expired mid-use. Renew it silently and replay the
        // request — the user should never see this happen.
        if (e.requestOptions.extra[_retriedKey] != true &&
            await ref.read(sessionRefresherProvider).refresh()) {
          final retry = e.requestOptions
            ..extra = {...e.requestOptions.extra, _retriedKey: true}
            ..headers['Authorization'] = 'Bearer ${ref.read(authTokenProvider)}';
          try {
            return handler.resolve(await dio.fetch(retry));
          } catch (retryError) {
            if (retryError is DioException) return handler.next(retryError);
            return handler.next(e);
          }
        }

        // No refresh token, or it was rejected: this really is a signed-out user.
        ref.read(authTokenProvider.notifier).state = null;
        ref.read(refreshTokenProvider.notifier).state = null;
        ref.read(unauthorizedProvider.notifier).state++;
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

/// Periodic API reachability status provider (true = Online, false = Unreachable).
final apiHealthProvider = FutureProvider<bool>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<dynamic>('/api/v1/ping').timeout(const Duration(seconds: 4));
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
});
