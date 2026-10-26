// Only the API saying "no" (a 401 from /auth/refresh) may sign a driver out.
// Before this, any failure to renew did: no signal at the depot,
// a timeout, a server blip. And a rotated token saved only by a fire-and-forget
// listener could be lost to an app kill, then replayed as "theft".

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/network/api_client.dart';
import 'package:mapcars_driver/src/features/auth/models/auth_session.dart';
import 'package:mapcars_driver/src/features/auth/providers/auth_notifier.dart';
import 'package:mapcars_driver/src/features/auth/services/driver_auth_service.dart';
import 'package:mapcars_driver/src/features/auth/services/session_repository.dart';

/// Answers every request with [respond] instead of touching the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

Future<ResponseBody> _offline(RequestOptions _) async =>
    throw const SocketException('offline');

Dio _refreshDio(Future<ResponseBody> Function(RequestOptions) respond) =>
    Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = _StubAdapter(respond);

class _MemorySessionRepository extends SessionRepository {
  _MemorySessionRepository() : super(const FlutterSecureStorage());

  AuthSession? saved;

  @override
  Future<void> save(AuthSession session) async => saved = session;

  @override
  Future<AuthSession?> load() async => saved;

  @override
  Future<void> clear() async => saved = null;
}

class _FakeAuthService extends DriverAuthService {
  _FakeAuthService() : super(Dio());

  @override
  Future<void> logout(String refreshToken) async {}
}

AuthSession _session({required bool expired}) => AuthSession(
      token: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: expired
          ? DateTime.now().subtract(const Duration(minutes: 5))
          : DateTime.now().add(const Duration(minutes: 30)),
      userId: 'driver-1',
      email: 'james@example.com',
      isProfileComplete: true,
      isEmailVerified: true,
      isPhoneVerified: true,
    );

void main() {
  late _MemorySessionRepository repo;

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://api.test');
    repo = _MemorySessionRepository();
  });

  ProviderContainer containerWith(
      Future<ResponseBody> Function(RequestOptions) refreshReply) {
    final container = ProviderContainer(overrides: [
      driverAuthServiceProvider.overrideWithValue(_FakeAuthService()),
      sessionRepositoryProvider.overrideWithValue(repo),
      refreshDioProvider.overrideWithValue(_refreshDio(refreshReply)),
      sessionPersistProvider.overrideWith(persistRenewedSession),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('a 401 from refresh is reported as rejected', () async {
    final container =
        containerWith((_) async => _json(401, {'title': 'expired'}));
    container.read(refreshTokenProvider.notifier).state = 'refresh-1';

    expect(await container.read(sessionRefresherProvider).refresh(),
        RefreshOutcome.rejected);
  });

  test('offline, a 500 or a 429 from refresh is failed, and keeps the tokens',
      () async {
    for (final reply in <Future<ResponseBody> Function(RequestOptions)>[
      _offline,
      (_) async => _json(500, {'title': 'boom'}),
      (_) async => _json(429, {'title': 'slow down'}),
    ]) {
      final container = containerWith(reply);
      container.read(authTokenProvider.notifier).state = 'access-1';
      container.read(refreshTokenProvider.notifier).state = 'refresh-1';

      expect(await container.read(sessionRefresherProvider).refresh(),
          RefreshOutcome.failed);
      expect(container.read(authTokenProvider), 'access-1');
      expect(container.read(refreshTokenProvider), 'refresh-1');
    }
  });

  test('a renewed session is on disk before refresh() returns', () async {
    final container = containerWith((_) async => _json(200, {
          'token': 'access-2',
          'refreshToken': 'refresh-2',
          'expiresInMinutes': 60,
        }));
    repo.saved = _session(expired: false);
    await container.read(authNotifierProvider.notifier).restore();

    final outcome = await container.read(sessionRefresherProvider).refresh();

    expect(outcome, RefreshOutcome.renewed);
    expect(repo.saved?.refreshToken, 'refresh-2');
    expect(container.read(refreshTokenProvider), 'refresh-2');
  });

  test('restore() offline keeps the driver signed in', () async {
    final container = containerWith(_offline);
    repo.saved = _session(expired: true);

    await container.read(authNotifierProvider.notifier).restore();

    expect(container.read(authNotifierProvider).isAuthenticated, isTrue);
    expect(container.read(authTokenProvider), 'access-1');
    expect(repo.saved, isNotNull);
  });

  test('restore() signs out when the API rejects the refresh token', () async {
    final container =
        containerWith((_) async => _json(401, {'title': 'expired'}));
    repo.saved = _session(expired: true);

    await container.read(authNotifierProvider.notifier).restore();

    expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
    expect(repo.saved, isNull);
  });

  test('a 401 while refresh is unreachable keeps the session', () async {
    final container = containerWith(_offline);
    container.read(authTokenProvider.notifier).state = 'access-1';
    container.read(refreshTokenProvider.notifier).state = 'refresh-1';
    final dio = container.read(dioProvider)
      ..httpClientAdapter =
          _StubAdapter((_) async => _json(401, {'title': 'expired'}));

    await expectLater(dio.get<dynamic>('/api/v1/auth/drivers/me'),
        throwsA(isA<DioException>()));

    expect(container.read(unauthorizedProvider), 0);
    expect(container.read(authTokenProvider), 'access-1');
    expect(container.read(refreshTokenProvider), 'refresh-1');
  });
}
