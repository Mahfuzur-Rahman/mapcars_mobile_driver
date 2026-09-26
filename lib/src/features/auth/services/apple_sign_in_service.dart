import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thrown when the Apple flow can't produce an identity token. The message is
/// user-facing — screens show it in the standard error banner.
class AppleSignInFailure implements Exception {
  const AppleSignInFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What `POST /api/v1/auth/drivers/apple` needs from Apple.
class AppleCredential {
  const AppleCredential({
    required this.idToken,
    required this.rawNonce,
    this.fullName,
  });

  final String idToken;

  /// The *unhashed* nonce. Apple embeds only its SHA-256 in the token; the API
  /// hashes this and compares, which is what proves the token was minted for
  /// this sign-in and not replayed from another.
  final String rawNonce;

  /// Apple returns the name on the **first** authorisation only — every later
  /// sign-in gets null, so the API must keep what it was sent the first time.
  final String? fullName;
}

/// Nonce generation for Sign in with Apple, kept apart so it can be tested.
class AppleNonce {
  const AppleNonce._();

  static const _charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';

  /// A random nonce from a cryptographically secure source. Predictable nonces
  /// defeat the point: the replay protection is only as good as the guess.
  static String generate({int length = 32, Random? random}) {
    final rng = random ?? Random.secure();
    return List.generate(length, (_) => _charset[rng.nextInt(_charset.length)])
        .join();
  }

  /// Lower-case hex SHA-256 — the form Apple expects in the request and puts
  /// in the token's `nonce` claim.
  static String sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}

/// Wraps the native "Sign in with Apple" sheet and hands back what the API
/// verifies. iOS only: App Review 4.8 requires it there because Google is
/// offered, and Android has no native Apple sheet worth the web-flow set-up.
class AppleSignInService {
  const AppleSignInService();

  /// Whether to show the button at all.
  static bool get isAvailable => !kIsWeb && Platform.isIOS;

  /// Opens Apple's sheet.
  ///
  /// Returns `null` if the user cancelled (not an error — screens stay put).
  /// Throws [AppleSignInFailure] for anything else.
  Future<AppleCredential?> obtainCredential() async {
    final rawNonce = AppleNonce.generate();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: AppleNonce.sha256Hex(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      if (kDebugMode) debugPrint('[apple] sign-in failed: ${e.code} ${e.message}');
      throw const AppleSignInFailure(
        "Couldn't sign in with Apple. Please try again, or use your phone or email instead.",
      );
    } catch (e) {
      // Raw platform errors mean nothing to a driver — log, show a sentence.
      if (kDebugMode) debugPrint('[apple] sign-in failed: $e');
      throw const AppleSignInFailure(
        "Couldn't sign in with Apple. Please try again, or use your phone or email instead.",
      );
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AppleSignInFailure(
        'Apple did not return a sign-in token. Please try again.',
      );
    }

    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');

    return AppleCredential(
      idToken: idToken,
      rawNonce: rawNonce,
      fullName: name.isEmpty ? null : name,
    );
  }
}

final appleSignInServiceProvider =
    Provider<AppleSignInService>((ref) => const AppleSignInService());
