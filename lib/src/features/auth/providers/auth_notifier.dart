import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/friendly_error.dart';
import '../models/auth_state.dart';
import '../services/driver_auth_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/session_repository.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._service, this._ref) : super(const AuthState());

  final DriverAuthService _service;
  final Ref _ref;

  // ── Phone flow ─────────────────────────────────────────────────────────────

  Future<bool> sendPhoneOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.sendPhoneOtp(phone);
      state = state.copyWith(
        isLoading: false,
        pendingPhone: phone,
        devOtpCode: result.devCode,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  Future<bool> verifyPhoneOtp(String code) async {
    final phone = state.pendingPhone;
    if (phone == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.verifyPhoneOtp(phone, code);
      await _applyAuth(result);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  // ── Email flow ─────────────────────────────────────────────────────────────

  Future<bool> signUpWithEmail(
      String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.signUpWithEmail(email, password, fullName);
      state = state.copyWith(
        isLoading: false,
        email: email,
        devOtpCode: result.devCode,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  Future<bool> resendEmailOtp(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.resendEmailOtp(email);
      state = state.copyWith(
        isLoading: false,
        email: email,
        devOtpCode: result.devCode,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  Future<bool> verifyEmailOtp(String email, String code) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.verifyEmailOtp(email, code);
      await _applyAuth(result);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.loginWithEmail(email, password);
      await _applyAuth(result);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: friendlyError(e),
      );
      return false;
    }
  }

  // ── Google ─────────────────────────────────────────────────────────────────

  /// Full "Continue with Google" flow: account picker → ID token → API.
  ///
  /// Returns false without setting an error when the driver dismisses the
  /// picker, so the screen simply stays put.
  Future<bool> continueWithGoogle({bool signUp = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final idToken =
          await _ref.read(googleSignInServiceProvider).obtainIdToken();
      if (idToken == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      final result = await _service.signInWithGoogle(idToken, signUp: signUp);
      await _applyAuth(result);
      return true;
    } on GoogleSignInFailure catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle(String idToken, {bool signUp = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.signInWithGoogle(idToken, signUp: signUp);
      await _applyAuth(result);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  /// Fetches the full profile (name, DOB, address, national ID, picture flag)
  /// — not part of [AuthState], since it isn't needed for session persistence.
  Future<DriverProfile?> loadProfile() async {
    try {
      return await _service.getProfile();
    } catch (e) {
      state = state.copyWith(error: friendlyError(e));
      return null;
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? email,
    DateTime? dateOfBirth,
    String? address,
    required String nationalIdNumber,
    String? drivingLicenceNumber,
    String? passportNumber,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? marketingConsent,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _service.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
        dateOfBirth: dateOfBirth,
        address: address,
        nationalIdNumber: nationalIdNumber,
        drivingLicenceNumber: drivingLicenceNumber,
        passportNumber: passportNumber,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        marketingConsent: marketingConsent,
      );
      state = state.copyWith(
        isLoading: false,
        fullName: profile.fullName,
        email: profile.email,
        isProfileComplete: profile.isProfileComplete,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  Future<bool> uploadProfilePicture(File file) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.uploadProfilePicture(file);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  // ── Session lifecycle ────────────────────────────────────────────────────

  /// Restore a persisted session on app launch. Drops it if missing/expired.
  Future<void> restore() async {
    final repo = _ref.read(sessionRepositoryProvider);
    final session = await repo.load();
    if (session == null) return;

    // Both tokens go back into the Dio providers before anything else, because
    // the refresh call below needs the refresh token to be there.
    _ref.read(authTokenProvider.notifier).state = session.token;
    _ref.read(refreshTokenProvider.notifier).state = session.refreshToken;
    state = AuthState.fromSession(session);

    if (!session.isExpired) return;

    // The access token lapsed while the app was closed. That used to be the end
    // of the session - the driver was dropped at the login screen having done
    // nothing wrong. Now we renew it silently and they never notice.
    final renewed = await _ref.read(sessionRefresherProvider).refresh();
    if (renewed) return; // the sessionRenewed listener persists the new tokens

    // The refresh token is dead too (revoked, or 90 days idle). This is the one
    // case where signing in again is genuinely required.
    await signOut();
  }

  /// Folds silently-renewed credentials into the session and re-persists them.
  /// Driven by [sessionRenewedProvider], which core bumps after a successful
  /// refresh - core announces, this feature reacts, and core never imports it.
  Future<void> adoptRenewedSession(RenewedSession renewed) async {
    if (state.token == null) return; // signed out mid-flight; nothing to adopt
    state = state.copyWith(
      token: renewed.token,
      refreshToken: renewed.refreshToken,
      expiresAt: DateTime.now().add(Duration(minutes: renewed.expiresInMinutes)),
    );
    await _persistSession();
  }

  Future<void> signOut() async {
    // Kill the session server-side first, while we still hold the token that
    // identifies it. Without this the refresh token stays valid for its full
    // life, so a copy lifted off the device would outlive "log out" entirely.
    // Best-effort: being offline must never trap someone in a signed-in app.
    final refreshToken = _ref.read(refreshTokenProvider);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _service.logout(refreshToken);
      } catch (_) {
        /* local sign-out proceeds regardless */
      }
    }

    _ref.read(authTokenProvider.notifier).state = null;
    _ref.read(refreshTokenProvider.notifier).state = null;
    _ref.read(sessionRenewedProvider.notifier).state = null;
    await _ref.read(sessionRepositoryProvider).clear();
    // Otherwise the next Google tap silently reuses the same account.
    await _ref.read(googleSignInServiceProvider).signOut();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _applyAuth(AuthResult result) async {
    // Write token into the Dio interceptor provider.
    _ref.read(authTokenProvider.notifier).state = result.token;
    final expiresAt =
        DateTime.now().add(Duration(minutes: result.expiresInMinutes));
    state =
        result.toAuthState().copyWith(isLoading: false, expiresAt: expiresAt);

    await _persistSession();
  }

  /// Writes the current [state] to secure storage so the driver stays signed
  /// in across restarts, and any profile edits survive an app restart too.
  Future<void> _persistSession() async {
    final session = state.toSession();
    if (session != null) {
      await _ref.read(sessionRepositoryProvider).save(session);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.watch(driverAuthServiceProvider), ref);

  // When the API rejects our token (HTTP 401), tear the session down so the
  // route guards bounce the driver back to sign-in. The signal is a core-level
  // leaf provider, keeping core/ independent of this feature.
  ref.listen<int>(unauthorizedProvider, (prev, next) {
    if (next > 0) notifier.signOut();
  });

  // A silent refresh succeeded — fold the rotated credentials into the session
  // and write them to storage, so the next app launch starts from the new pair
  // rather than the retired one.
  ref.listen<RenewedSession?>(sessionRenewedProvider, (prev, next) {
    if (next != null) notifier.adoptRenewedSession(next);
  });

  return notifier;
});
