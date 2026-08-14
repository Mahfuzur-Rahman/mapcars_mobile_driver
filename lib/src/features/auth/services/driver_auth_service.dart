import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../demo_credentials.dart';
import '../models/auth_state.dart';

/// Result from `GET/PATCH /me` — the driver's full profile, richer than
/// [AuthResult] (which is shared with login/signup for both roles).
class DriverProfile {
  const DriverProfile({
    required this.driverId,
    this.firstName,
    this.lastName,
    this.fullName,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.address,
    this.nationalIdNumber,
    this.drivingLicenceNumber,
    this.passportNumber,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.marketingConsent = false,
    required this.hasProfilePicture,
    required this.isProfileComplete,
    this.status = 'PendingApproval',
    this.isOnline = false,
    this.lastOnlineAtUtc,
    this.averageRating,
    this.ratingCount = 0,
    this.cancellationCount = 0,
    this.noShowCount = 0,
    this.createdAtUtc,
  });

  final String driverId;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? address;
  final String? nationalIdNumber;
  final String? drivingLicenceNumber;
  final String? passportNumber;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool marketingConsent;
  final bool hasProfilePicture;
  final bool isProfileComplete;

  /// "PendingApproval" | "Approved" | "Suspended" | "Rejected" — a driver
  /// can only go online once an admin has set this to "Approved".
  final String status;
  final bool isOnline;
  final DateTime? lastOnlineAtUtc;
  final double? averageRating;
  final int ratingCount;
  final int cancellationCount;
  final int noShowCount;
  final DateTime? createdAtUtc;

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
        driverId: j['driverId'].toString(),
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
        fullName: j['fullName'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        dateOfBirth: j['dateOfBirth'] == null
            ? null
            : DateTime.parse(j['dateOfBirth'] as String),
        address: j['address'] as String?,
        nationalIdNumber: j['nationalIdNumber'] as String?,
        drivingLicenceNumber: j['drivingLicenceNumber'] as String?,
        passportNumber: j['passportNumber'] as String?,
        emergencyContactName: j['emergencyContactName'] as String?,
        emergencyContactPhone: j['emergencyContactPhone'] as String?,
        marketingConsent: j['marketingConsent'] as bool? ?? false,
        hasProfilePicture: j['hasProfilePicture'] as bool? ?? false,
        isProfileComplete: j['isProfileComplete'] as bool? ?? false,
        status: j['status'] as String? ?? 'PendingApproval',
        isOnline: j['isOnline'] as bool? ?? false,
        lastOnlineAtUtc: j['lastOnlineAtUtc'] == null
            ? null
            : DateTime.parse(j['lastOnlineAtUtc'] as String),
        averageRating: (j['averageRating'] as num?)?.toDouble(),
        ratingCount: j['ratingCount'] as int? ?? 0,
        cancellationCount: j['cancellationCount'] as int? ?? 0,
        noShowCount: j['noShowCount'] as int? ?? 0,
        createdAtUtc: j['createdAtUtc'] == null
            ? null
            : DateTime.parse(j['createdAtUtc'] as String),
      );
}

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
    this.refreshToken,
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

  /// Long-lived credential for `POST /api/v1/auth/refresh`. Absent only if the
  /// API predates refresh tokens.
  final String? refreshToken;

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
        refreshToken: j['refreshToken'] as String?,
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
        refreshToken: refreshToken,
        userId: userId,
        fullName: fullName,
        email: email,
        phone: phone,
        isProfileComplete: isProfileComplete,
        isEmailVerified: isEmailVerified,
        isPhoneVerified: isPhoneVerified,
      );

  /// A synthetic result for the offline demo driver (no API call). See
  /// [DemoCredentials] — used while the backend is not reachable.
  factory AuthResult.demo() => const AuthResult(
        token: DemoCredentials.token,
        expiresInMinutes: DemoCredentials.sessionMinutes,
        userId: DemoCredentials.userId,
        fullName: DemoCredentials.fullName,
        email: DemoCredentials.email,
        phone: DemoCredentials.phone,
        isProfileComplete: true,
        isEmailVerified: true,
        isPhoneVerified: true,
      );
}

/// Talks to the driver auth endpoints. Mirrors
/// `Mapcars.Api/Controllers/DriverAuthController.cs` (`/api/v1/auth/drivers`).
class DriverAuthService {
  DriverAuthService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/auth/drivers';

  /// Revokes this device's refresh token server-side. Shared across roles, so it
  /// lives at `/api/v1/auth/logout` rather than under the per-role base above.
  ///
  /// Always succeeds from the caller's point of view: the API answers 204 even
  /// for a token it has never seen, because signing out twice is not an error.
  Future<void> logout(String refreshToken) => apiCall(() async {
        await _dio.post<void>(
          '/api/v1/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      });

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

  Future<OtpSentResult> resendEmailOtp(String email) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/resend-email',
          data: {'email': email},
        );
        final d = res.data!;
        return OtpSentResult(
          message: d['message'] as String? ?? 'Code resent.',
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

  /// `signUp` must only be true from a sign-up surface. From a sign-in screen
  /// it stays false, so the API refuses to invent an account for a Google
  /// address that has never signed up.
  Future<AuthResult> signInWithGoogle(String idToken, {bool signUp = false}) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/google',
          data: {'idToken': idToken, 'signUp': signUp},
        );
        return AuthResult.fromJson(res.data!);
      });

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<DriverProfile> getProfile() => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/me');
        return DriverProfile.fromJson(res.data!);
      });

  Future<DriverProfile> updateProfile({
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
  }) =>
      apiCall(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          '$_base/me',
          data: {
            'firstName': firstName,
            'lastName': lastName,
            if (email != null && email.isNotEmpty) 'email': email,
            if (dateOfBirth != null)
              'dateOfBirth':
                  '${dateOfBirth.year.toString().padLeft(4, '0')}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}',
            if (address != null && address.isNotEmpty) 'address': address,
            'nationalIdNumber': nationalIdNumber,
            if (drivingLicenceNumber != null && drivingLicenceNumber.isNotEmpty)
              'drivingLicenceNumber': drivingLicenceNumber,
            if (passportNumber != null && passportNumber.isNotEmpty)
              'passportNumber': passportNumber,
            if (emergencyContactName != null && emergencyContactName.isNotEmpty)
              'emergencyContactName': emergencyContactName,
            if (emergencyContactPhone != null && emergencyContactPhone.isNotEmpty)
              'emergencyContactPhone': emergencyContactPhone,
            if (marketingConsent != null) 'marketingConsent': marketingConsent,
          },
        );
        return DriverProfile.fromJson(res.data!);
      });

  /// `PATCH /me/availability` — flips the driver online/offline. Returns the
  /// refreshed profile (now carrying `isOnline`/`lastOnlineAtUtc`).
  Future<DriverProfile> setAvailability(bool isOnline) => apiCall(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          '$_base/me/availability',
          data: {'isOnline': isOnline},
        );
        return DriverProfile.fromJson(res.data!);
      });

  Future<DriverProfile> uploadProfilePicture(File file) => apiCall(() async {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path),
        });
        final res = await _dio.put<Map<String, dynamic>>(
          '$_base/me/picture',
          data: formData,
        );
        return DriverProfile.fromJson(res.data!);
      });

  /// URL to fetch the driver's profile picture. Pass with an `Authorization`
  /// header (see `Image.network(..., headers: ...)`).
  String profilePictureUrl(String baseUrl) => '$baseUrl$_base/me/picture';

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      apiCall(() async {
        await _dio.post<void>(
          '$_base/me/change-password',
          data: {
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          },
        );
      });
}

final driverAuthServiceProvider = Provider<DriverAuthService>(
  (ref) => DriverAuthService(ref.watch(dioProvider)),
);
