import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../utils/server_clock.dart';
import 'api_exception.dart';
import 'network_diagnosis.dart';

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

/// Credentials handed back by `POST /api/v1/auth/refresh`.
class RenewedSession {
  const RenewedSession({
    required this.token,
    required this.refreshToken,
    required this.expiresInMinutes,
  });

  final String token;

  /// The API rotates on every refresh, so this is a *different* token from the
  /// one that was sent. Storing it is mandatory. Presenting the old one again,
  /// after the API's short grace window, reads as a stolen-token replay and
  /// kills every session for the account.
  final String refreshToken;

  final int expiresInMinutes;
}

/// What became of an attempt to renew the session.
enum RefreshOutcome {
  /// New tokens are in the providers and on disk.
  renewed,

  /// The API answered 401 (the refresh token is expired, revoked or replayed),
  /// or there was none to send. Signing in again is genuinely required.
  rejected,

  /// No usable answer: offline, timeout, 5xx, 429. The session may be
  /// perfectly fine, so it is kept and the next request tries again.
  failed,
}

/// Writes renewed credentials to durable storage. Core can't import the auth
/// feature, so the app root (`main.dart`) installs the real one
/// (`persistRenewedSession`). The refresher awaits it before reporting success:
/// a rotated refresh token that lived only in memory would be replayed after an
/// app kill.
final sessionPersistProvider =
    Provider<Future<void> Function(RenewedSession)>((ref) {
  throw UnimplementedError(
      'Override sessionPersistProvider at the app root (see persistRenewedSession).');
});

/// The bare Dio the refresher talks to. A bare instance on purpose: the app's
/// own carries the interceptor below, so refreshing through it would recurse
/// on failure. It's its own provider so tests can stub the network.
final refreshDioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    )));

/// Exchanges the stored refresh token for a fresh access token.
class SessionRefresher {
  SessionRefresher(this._ref);

  final Ref _ref;

  /// The refresh currently in flight, if any.
  ///
  /// Coalescing matters more than it looks. Several requests can 401 at the same
  /// instant (the home screen alone fires a few). Because the API *rotates*
  /// the refresh token on use, a second concurrent call would present a token
  /// that was just retired. Parallel callers therefore all await this one future.
  Future<RefreshOutcome>? _inFlight;

  Future<RefreshOutcome> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _run();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<RefreshOutcome> _run() async {
    final refreshToken = _ref.read(refreshTokenProvider);
    if (refreshToken == null || refreshToken.isEmpty) {
      return RefreshOutcome.rejected;
    }
    // Read before the try: a missing override is a wiring bug and must fail
    // loudly, not be mistaken for being offline.
    final persist = _ref.read(sessionPersistProvider);

    final RenewedSession renewed;
    try {
      final res = await _ref.read(refreshDioProvider).post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data;
      if (data == null || data['token'] is! String) return RefreshOutcome.failed;
      renewed = RenewedSession(
        token: data['token'] as String,
        refreshToken: data['refreshToken'] as String? ?? refreshToken,
        expiresInMinutes: data['expiresInMinutes'] as int? ?? 60,
      );
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[API] refresh failed: $e');
      // Only the API saying no ends the session. Anything else is the network
      // or a passing server fault, and the next request will try again.
      return e.response?.statusCode == 401
          ? RefreshOutcome.rejected
          : RefreshOutcome.failed;
    } catch (e) {
      if (kDebugMode) debugPrint('[API] refresh failed: $e');
      return RefreshOutcome.failed;
    }

    _ref.read(authTokenProvider.notifier).state = renewed.token;
    _ref.read(refreshTokenProvider.notifier).state = renewed.refreshToken;
    // On disk before anyone relies on it. A storage failure is logged, not
    // fatal: the tokens are live in memory, and the next save retries.
    try {
      await persist(renewed);
    } catch (e) {
      if (kDebugMode) debugPrint('[API] could not persist renewed session: $e');
    }
    return RefreshOutcome.renewed;
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
      onResponse: (response, handler) {
        // Every response carries a Date header, so keeping the server-clock
        // offset current costs nothing extra. Request countdowns on the board
        // are measured against it rather than the device clock.
        ServerClock.syncFrom(response.headers.value('date'));
        handler.next(response);
      },
      onError: (e, handler) async {
        if (kDebugMode) {
          debugPrint(
            '[API] ${e.requestOptions.method} ${e.requestOptions.path} '
            '→ ${e.response?.statusCode} ${e.message}',
          );
        }

        // The API was never reached, so it logged nothing: find out why from
        // the phone's side, and carry the answer to the error message.
        if (isUnreachable(e)) {
          e.requestOptions.extra = {
            ...e.requestOptions.extra,
            networkDiagnosisKey: await NetworkDiagnoser.shared.diagnose(),
          };
          return handler.next(e);
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
        // request. The user should never see this happen.
        if (e.requestOptions.extra[_retriedKey] != true) {
          final outcome = await ref.read(sessionRefresherProvider).refresh();
          if (outcome == RefreshOutcome.renewed) {
            final retry = e.requestOptions
              ..extra = {...e.requestOptions.extra, _retriedKey: true}
              ..headers['Authorization'] =
                  'Bearer ${ref.read(authTokenProvider)}';
            try {
              return handler.resolve(await dio.fetch(retry));
            } catch (retryError) {
              if (retryError is DioException) return handler.next(retryError);
              return handler.next(e);
            }
          }
          // Couldn't reach the API to renew. The session isn't over: keep the
          // tokens and let this request fail like any other network error. The
          // next request renews.
          if (outcome == RefreshOutcome.failed) return handler.next(e);
        }

        // The refresh token was rejected, or this request 401'd again right
        // after a renewal: this really is a signed-out user.
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
