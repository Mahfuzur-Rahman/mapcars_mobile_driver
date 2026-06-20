import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/auth_state.dart';
import '../services/driver_auth_service.dart';
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── Google ─────────────────────────────────────────────────────────────────

  Future<bool> signInWithGoogle(String idToken) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.signInWithGoogle(idToken);
      await _applyAuth(result);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── Session lifecycle ────────────────────────────────────────────────────

  /// Restore a persisted session on app launch. Drops it if missing/expired.
  Future<void> restore() async {
    final repo = _ref.read(sessionRepositoryProvider);
    final session = await repo.load();
    if (session == null) return;
    if (session.isExpired) {
      await repo.clear();
      return;
    }
    _ref.read(authTokenProvider.notifier).state = session.token;
    state = AuthState.fromSession(session);
  }

  Future<void> signOut() async {
    _ref.read(authTokenProvider.notifier).state = null;
    await _ref.read(sessionRepositoryProvider).clear();
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

    // Persist so the driver stays signed in across restarts.
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

  return notifier;
});
