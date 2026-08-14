// Unit tests for the auth session/state logic — the part of the app most worth
// guarding (persistence round-trips and session expiry). Pure Dart, so these run
// without platform channels (secure storage / dotenv) being available.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/auth/models/auth_session.dart';
import 'package:mapcars_driver/src/features/auth/models/auth_state.dart';

void main() {
  group('AuthSession', () {
    test('survives an encode → decode round-trip', () {
      final session = AuthSession(
        token: 'jwt-123',
        expiresAt: DateTime.parse('2030-01-01T00:00:00.000'),
        userId: 'driver-1',
        fullName: 'James Kowalski',
        email: 'james@example.com',
        phone: '+447700900812',
        isProfileComplete: true,
        isEmailVerified: false,
        isPhoneVerified: true,
      );

      final restored = AuthSession.decode(session.encode());

      expect(restored.token, session.token);
      expect(restored.expiresAt, session.expiresAt);
      expect(restored.userId, session.userId);
      expect(restored.fullName, session.fullName);
      expect(restored.isPhoneVerified, isTrue);
      expect(restored.isEmailVerified, isFalse);
    });

    test('carries the refresh token through a round-trip', () {
      // The refresh token is what keeps a driver signed in past the access
      // token's one-hour life. Losing it in storage would silently restore the
      // old "signed out mid-shift" behaviour.
      final session = AuthSession(
        token: 'jwt-123',
        refreshToken: 'refresh-abc',
        expiresAt: DateTime.parse('2030-01-01T00:00:00.000'),
        userId: 'driver-1',
        isProfileComplete: false,
        isEmailVerified: false,
        isPhoneVerified: true,
      );

      expect(AuthSession.decode(session.encode()).refreshToken, 'refresh-abc');
    });

    test('tolerates a session persisted before refresh tokens existed', () {
      // Sessions already on disk have no refreshToken key. Decoding must not
      // throw — it should yield null and let the normal expiry path run.
      const legacy = '{"token":"t","expiresAt":"2030-01-01T00:00:00.000",'
          '"userId":"d","isProfileComplete":false,"isEmailVerified":false,'
          '"isPhoneVerified":true}';

      final decoded = AuthSession.decode(legacy);
      expect(decoded.refreshToken, isNull);
      expect(decoded.token, 't');
    });

    test('reports expiry against the wall clock', () {
      final expired = AuthSession(
        token: 't',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        userId: 'd',
        isProfileComplete: false,
        isEmailVerified: false,
        isPhoneVerified: true,
      );
      expect(expired.isExpired, isTrue);
    });
  });

  group('AuthState', () {
    test('is authenticated only with a live, unexpired token', () {
      const none = AuthState();
      expect(none.isAuthenticated, isFalse);

      final live = AuthState(
        token: 't',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        userId: 'd',
      );
      expect(live.isAuthenticated, isTrue);

      final stale = AuthState(
        token: 't',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        userId: 'd',
      );
      expect(stale.isAuthenticated, isFalse);
    });

    test('toSession() / fromSession() preserve the persistable slice', () {
      final state = AuthState(
        token: 't',
        expiresAt: DateTime.parse('2030-01-01T00:00:00.000'),
        userId: 'd',
        fullName: 'Jane',
        isProfileComplete: true,
        isPhoneVerified: true,
      );

      final session = state.toSession();
      expect(session, isNotNull);

      final back = AuthState.fromSession(session!);
      expect(back.token, 't');
      expect(back.userId, 'd');
      expect(back.fullName, 'Jane');
      expect(back.isProfileComplete, isTrue);
      // Transient fields are never carried through a session.
      expect(back.isLoading, isFalse);
      expect(back.error, isNull);
    });

    test('toSession() is null when unauthenticated', () {
      const state = AuthState(fullName: 'No token');
      expect(state.toSession(), isNull);
    });
  });
}
