import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_store.dart';
import '../models/auth_session.dart';

/// Persists the authenticated driver session to secure storage so the user
/// stays signed in across app restarts.
class SessionRepository {
  SessionRepository(this._store);

  final FlutterSecureStorage _store;
  static const _key = 'driver_session_v1';

  Future<void> save(AuthSession session) =>
      _store.write(key: _key, value: session.encode());

  Future<AuthSession?> load() async {
    final raw = await _store.read(key: _key);
    if (raw == null) return null;
    try {
      return AuthSession.decode(raw);
    } catch (_) {
      // Corrupt or schema-changed payload — drop it rather than crash on boot.
      await clear();
      return null;
    }
  }

  Future<void> clear() => _store.delete(key: _key);
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(secureStoreProvider)),
);
