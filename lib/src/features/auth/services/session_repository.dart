import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_store.dart';
import '../models/auth_session.dart';

/// Persists the authenticated driver session to secure storage so the user
/// stays signed in across app restarts.
class SessionRepository {
  /// [previous] is the store older builds wrote with (defaults to [store]).
  SessionRepository(FlutterSecureStorage store, [FlutterSecureStorage? previous])
      : _store = store,
        _previous = previous ?? store;

  final FlutterSecureStorage _store;
  final FlutterSecureStorage _previous;

  /// v2: written with the `first_unlock` keychain options (see secure_store).
  /// It's a new key rather than a rewrite of the old one, so deleting the old
  /// copy can never take the new one with it, whatever the keychain query
  /// matches on.
  static const _key = 'driver_session_v2';

  /// Written by builds before 2026-10, under the default keychain options.
  static const _previousKey = 'driver_session_v1';

  Future<void> save(AuthSession session) =>
      _store.write(key: _key, value: session.encode());

  Future<AuthSession?> load() async {
    final String? raw;
    try {
      raw = await _store.read(key: _key) ?? await _migrate();
    } catch (_) {
      // Unreadable storage. A backup restored onto another phone can't decrypt
      // Keystore-bound data, and the keychain can refuse a read while locked.
      // Start signed out rather than hang the splash. Nothing is deleted, so
      // a locked-phone launch still finds the session next time.
      return null;
    }
    if (raw == null) return null;
    try {
      return AuthSession.decode(raw);
    } catch (_) {
      // Corrupt or schema-changed payload: drop it rather than crash on boot.
      await clear();
      return null;
    }
  }

  /// Carries a session written by an older build onto the current key and
  /// options, then deletes the old copy. Runs at most once per install.
  Future<String?> _migrate() async {
    final raw = await _previous.read(key: _previousKey);
    if (raw == null) return null;
    await _store.write(key: _key, value: raw);
    await _previous.delete(key: _previousKey);
    return raw;
  }

  Future<void> clear() async {
    await _store.delete(key: _key);
    // Retire the older copy too, or signing out would leave behind a session
    // the migration above would cheerfully restore on next launch.
    await _previous.delete(key: _previousKey);
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(
    ref.watch(secureStoreProvider),
    ref.watch(legacySecureStoreProvider),
  ),
);
