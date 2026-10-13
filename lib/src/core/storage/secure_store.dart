import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-backed secure storage (Android Keystore / iOS Keychain).
///
/// Used to persist the driver's auth session across app restarts. This is the
/// only place secrets touch the device; everything else flows through the API.
///
/// iOS uses `first_unlock`, so the session can be read while the phone is
/// locked. A driver's phone is locked in a cradle for hours, and iOS can wake
/// the app in the background. Under the default (readable only while unlocked)
/// that launch found its own session unreadable. Android options are untouched:
/// changing them would make every existing session unreadable.
final secureStoreProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  ),
);

/// The store as every build before 2026-10 wrote it (iOS default: readable
/// only while unlocked). Only ever read, and then deleted from, to carry an
/// existing session across. See `SessionRepository.load`.
final legacySecureStoreProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);
