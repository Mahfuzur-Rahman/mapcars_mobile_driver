// Sign in with Apple nonce handling.
//
// The API verifies an Apple token by hashing the raw nonce we send it and
// comparing with the token's `nonce` claim — which Apple copies from whatever
// we passed to the sheet. So the sheet must get the SHA-256 hex and the API
// the raw value; swap them, or hash in a different encoding, and every Apple
// sign-in fails server-side with nothing visibly wrong in the app.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/auth/services/apple_sign_in_service.dart';

void main() {
  group('AppleNonce.generate', () {
    test('defaults to 32 characters from the URL-safe charset', () {
      final nonce = AppleNonce.generate();
      expect(nonce, hasLength(32));
      expect(nonce, matches(RegExp(r'^[0-9A-Za-z\-._]+$')));
    });

    test('honours a requested length', () {
      expect(AppleNonce.generate(length: 64), hasLength(64));
    });

    test('is not repeated between sign-ins', () {
      final seen = {for (var i = 0; i < 200; i++) AppleNonce.generate()};
      expect(seen, hasLength(200));
    });

    test('is deterministic only when a seeded source is injected', () {
      expect(
        AppleNonce.generate(random: Random(1)),
        AppleNonce.generate(random: Random(1)),
      );
    });
  });

  group('AppleNonce.sha256Hex', () {
    test('is lower-case hex SHA-256 of the UTF-8 bytes', () {
      // Known vector: SHA-256("abc").
      expect(
        AppleNonce.sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('differs from the raw nonce it hashes', () {
      final raw = AppleNonce.generate();
      final hashed = AppleNonce.sha256Hex(raw);
      expect(hashed, isNot(raw));
      expect(hashed, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  // Without the entitlement the Apple sheet fails at runtime on a real device —
  // invisible in the simulator-less CI and in every widget test.
  test('both iOS entitlements files carry Sign in with Apple', () {
    for (final path in [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/RunnerRelease.entitlements',
    ]) {
      final plist = File(path).readAsStringSync();
      expect(
        plist,
        matches(RegExp(
          r'<key>com\.apple\.developer\.applesignin</key>\s*<array>\s*<string>Default</string>\s*</array>',
        )),
        reason: path,
      );
    }
  });
}
