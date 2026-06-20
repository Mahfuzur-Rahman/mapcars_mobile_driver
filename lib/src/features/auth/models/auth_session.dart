import 'dart:convert';

/// The persisted slice of an authenticated driver — written to secure storage
/// after login and restored on the next app launch. Transient UI state
/// (loading flags, errors, dev OTP) lives in [AuthState] and is never persisted.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.userId,
    this.fullName,
    this.email,
    this.phone,
    required this.isProfileComplete,
    required this.isEmailVerified,
    required this.isPhoneVerified,
  });

  final String token;
  final DateTime expiresAt;
  final String userId;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool isProfileComplete;
  final bool isEmailVerified;
  final bool isPhoneVerified;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'token': token,
        'expiresAt': expiresAt.toIso8601String(),
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'isProfileComplete': isProfileComplete,
        'isEmailVerified': isEmailVerified,
        'isPhoneVerified': isPhoneVerified,
      };

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        token: j['token'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        userId: j['userId'] as String,
        fullName: j['fullName'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        isProfileComplete: j['isProfileComplete'] as bool? ?? false,
        isEmailVerified: j['isEmailVerified'] as bool? ?? false,
        isPhoneVerified: j['isPhoneVerified'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());

  factory AuthSession.decode(String raw) =>
      AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
