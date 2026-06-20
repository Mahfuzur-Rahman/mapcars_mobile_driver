import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/auth_state.dart';

/// Result from send-OTP / signup — wraps the API's OtpSentResponse.
class OtpSentResult {
  const OtpSentResult({required this.message, this.devCode});
  final String message;
  final String? devCode;
}

/// Result from any auth flow that returns a token — wraps the API's AuthResponse.
class AuthResult {
  const AuthResult({
    required this.token,
    required this.expiresInMinutes,
    required this.userId,
    this.fullName,
    this.email,
    this.phone,
    required this.isProfileComplete,
    required this.isEmailVerified,
    required this.isPhoneVerified,
  });

  final String token;
  final int expiresInMinutes;
  final String userId;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool isProfileComplete;
  final bool isEmailVerified;
  final bool isPhoneVerified;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        token: j['token'] as String,
        expiresInMinutes: j['expiresInMinutes'] as int? ?? 60,
        userId: j['userId'].toString(),
        fullName: j['fullName'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        isProfileComplete: j['isProfileComplete'] as bool? ?? false,
        isEmailVerified: j['isEmailVerified'] as bool? ?? false,
        isPhoneVerified: j['isPhoneVerified'] as bool? ?? false,
      );

  AuthState toAuthState() => AuthState(
        token: token,
        userId: userId,
        fullName: fullName,
        email: email,
        phone: phone,
        isProfileComplete: isProfileComplete,
        isEmailVerified: isEmailVerified,
        isPhoneVerified: isPhoneVerified,
      );
}

/// Talks to the driver auth endpoints. Mirrors
/// `Mapcars.Api/Controllers/DriverAuthController.cs` (`/api/v1/auth/drivers`).
class DriverAuthService {
  DriverAuthService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/auth/drivers';

  Future<OtpSentResult> sendPhoneOtp(String phone) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/send-otp',
          data: {'phone': phone},
        );
        final d = res.data!;
        return OtpSentResult(
          message: d['message'] as String? ?? 'OTP sent.',
          devCode: d['devCode'] as String?,
        );
      });

  Future<AuthResult> verifyPhoneOtp(String phone, String code) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/verify-phone',
          data: {'phone': phone, 'code': code},
        );
        return AuthResult.fromJson(res.data!);
      });

  Future<OtpSentResult> signUpWithEmail(
          String email, String password, String fullName) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/signup',
          data: {'email': email, 'password': password, 'fullName': fullName},
        );
        final d = res.data!;
        return OtpSentResult(
          message: d['message'] as String? ?? 'OTP sent.',
          devCode: d['devCode'] as String?,
        );
      });

  Future<AuthResult> verifyEmailOtp(String email, String code) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/verify-email',
          data: {'email': email, 'code': code},
        );
        return AuthResult.fromJson(res.data!);
      });

  Future<AuthResult> loginWithEmail(String email, String password) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/login',
          data: {'email': email, 'password': password},
        );
        return AuthResult.fromJson(res.data!);
      });

  Future<AuthResult> signInWithGoogle(String idToken) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/google',
          data: {'idToken': idToken},
        );
        return AuthResult.fromJson(res.data!);
      });
}

final driverAuthServiceProvider = Provider<DriverAuthService>(
  (ref) => DriverAuthService(ref.watch(dioProvider)),
);
