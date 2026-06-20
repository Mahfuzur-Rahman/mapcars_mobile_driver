import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-backed secure storage (Android Keystore / iOS Keychain).
///
/// Used to persist the driver's auth session across app restarts. This is the
/// only place secrets touch the device; everything else flows through the API.
final secureStoreProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);
