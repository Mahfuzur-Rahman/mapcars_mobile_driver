// A fresh sign-in must hand the refresh token to the Dio layer.
//
// `restore()` already did, but every sign-in path went through `_applyAuth`,
// which only set the access token. The refresh token reached AuthState and was
// persisted, yet `refreshTokenProvider` — the one the 401 interceptor reads —
// stayed null until the next app restart, so a driver who signed in and kept the
// app open was signed out when the one-hour access token lapsed, mid-shift.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/network/api_client.dart';
import 'package:mapcars_driver/src/features/auth/models/auth_session.dart';
import 'package:mapcars_driver/src/features/auth/providers/auth_notifier.dart';
import 'package:mapcars_driver/src/features/auth/services/driver_auth_service.dart';
import 'package:mapcars_driver/src/features/auth/services/session_repository.dart';

/// Every token-returning flow answers with [result], so the test exercises the
/// notifier's handling of it rather than any HTTP.
class _FakeAuthService extends DriverAuthService {
  _FakeAuthService(this.result) : super(Dio());

  final AuthResult result;

  @override
  Future<AuthResult> loginWithEmail(String email, String password) async =>
      result;

  @override
  Future<AuthResult> verifyEmailOtp(String email, String code) async => result;

  @override
  Future<AuthResult> verifyPhoneOtp(String phone, String code) async => result;

  @override
  Future<OtpSentResult> sendPhoneOtp(String phone) async =>
      const OtpSentResult(message: 'sent');

  @override
  Future<AuthResult> signInWithGoogle(String idToken,
          {bool signUp = false}) async =>
      result;
}

/// In-memory stand-in for secure storage (a platform channel in production).
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

AuthResult _result({String? refreshToken = 'refresh-xyz'}) => AuthResult(
      token: 'access-abc',
      refreshToken: refreshToken,
      expiresInMinutes: 60,
      userId: 'driver-1',
      fullName: 'James Kowalski',
      email: 'james@example.com',
      isProfileComplete: true,
      isEmailVerified: true,
      isPhoneVerified: true,
    );

({ProviderContainer container, _MemorySessionRepository sessions}) _harness(
    AuthResult result) {
  final sessions = _MemorySessionRepository();
  final container = ProviderContainer(overrides: [
    driverAuthServiceProvider.overrideWithValue(_FakeAuthService(result)),
    sessionRepositoryProvider.overrideWithValue(sessions),
  ]);
  addTearDown(container.dispose);
  return (container: container, sessions: sessions);
}

void main() {
  // Each entry is one way into the app; all of them end in `_applyAuth`.
  final flows = <String, Future<bool> Function(AuthNotifier)>{
    'email login': (n) => n.loginWithEmail('james@example.com', 'pw'),
    'email OTP verify (sign-up)': (n) =>
        n.verifyEmailOtp('james@example.com', '123456'),
    'phone OTP verify': (n) async {
      await n.sendPhoneOtp('+447700900812');
      return n.verifyPhoneOtp('123456');
    },
    'Google sign-in': (n) => n.signInWithGoogle('google-id-token'),
  };

  for (final entry in flows.entries) {
    test('${entry.key} sets refreshTokenProvider alongside the access token',
        () async {
      final h = _harness(_result());
      final notifier = h.container.read(authNotifierProvider.notifier);

      expect(await entry.value(notifier), isTrue);

      expect(h.container.read(authTokenProvider), 'access-abc');
      expect(h.container.read(refreshTokenProvider), 'refresh-xyz');
      // ...and the persisted session carries it, so a restart restores it too.
      expect(h.sessions.saved?.refreshToken, 'refresh-xyz');
    });
  }

  test('an API that returns no refresh token leaves the provider empty',
      () async {
    final h = _harness(_result(refreshToken: null));
    final notifier = h.container.read(authNotifierProvider.notifier);

    await notifier.loginWithEmail('james@example.com', 'pw');

    expect(h.container.read(authTokenProvider), 'access-abc');
    expect(h.container.read(refreshTokenProvider), isNull);
  });

  test('signing in again replaces a previous account\'s refresh token',
      () async {
    final h = _harness(_result(refreshToken: null));
    h.container.read(refreshTokenProvider.notifier).state = 'stale-refresh';
    final notifier = h.container.read(authNotifierProvider.notifier);

    await notifier.loginWithEmail('james@example.com', 'pw');

    expect(h.container.read(refreshTokenProvider), isNull,
        reason: 'a stale token must not be paired with the new access token');
  });
}
