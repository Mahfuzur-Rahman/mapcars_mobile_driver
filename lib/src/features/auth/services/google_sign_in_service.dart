import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/env.dart';

/// Thrown when the Google flow can't produce an ID token. The message is
/// user-facing — screens show it in the standard error banner.
class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Wraps the Google account picker and hands back the **ID token** that
/// `POST /api/v1/auth/drivers/google` verifies.
///
/// The API identifies the driver from that token alone, so nothing else about
/// the Google account is sent or stored.
///
/// Not configured yet: without `GOOGLE_SERVER_CLIENT_ID` in `.env` Google
/// returns no ID token, so this throws a plain-English [GoogleSignInFailure]
/// rather than failing silently. See `instruction.md`.
class GoogleSignInService {
  GoogleSignInService({GoogleSignIn? client}) : _client = client;

  final GoogleSignIn? _client;

  bool get isConfigured => Env.googleServerClientId.isNotEmpty;

  GoogleSignIn get _google =>
      _client ??
      GoogleSignIn(
        scopes: const ['email', 'profile'],
        // The OAuth *Web* client ID — this is what makes Google mint an ID
        // token whose audience our API can verify.
        serverClientId: Env.googleServerClientId,
      );

  /// Opens the Google account picker.
  ///
  /// Returns `null` if the user backed out (not an error — screens stay put).
  /// Throws [GoogleSignInFailure] when Google is unavailable or misconfigured.
  Future<String?> obtainIdToken() async {
    if (!isConfigured) {
      throw const GoogleSignInFailure(
        "Google sign-in isn't set up yet. Please use your phone or email for now.",
      );
    }

    final GoogleSignInAccount? account;
    try {
      account = await _google.signIn();
    } catch (e) {
      // Never surface the raw platform error — Google's failures arrive as
      // `PlatformException(sign_in_failed, ...ApiException: 10, null, null)`,
      // which is meaningless to a user. Log it, show a sentence.
      if (kDebugMode) debugPrint('[google] sign-in failed: $e');
      throw const GoogleSignInFailure(
        "Couldn't sign in with Google. Please try again, or use your phone or email instead.",
      );
    }
    if (account == null) return null; // user dismissed the picker

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleSignInFailure(
        'Google did not return a sign-in token. Please try again.',
      );
    }
    return idToken;
  }

  /// Clears the cached Google account so the next tap re-opens the picker.
  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await _google.signOut();
    } catch (_) {
      // Best-effort — our own session teardown is what actually matters.
    }
  }
}

final googleSignInServiceProvider =
    Provider<GoogleSignInService>((ref) => GoogleSignInService());
