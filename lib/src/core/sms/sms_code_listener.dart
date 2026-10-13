import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:smart_auth/smart_auth.dart';

/// Reads a sign-in code from an incoming SMS on Android, through Google's SMS
/// User Consent API. The user sees one system sheet ("Allow Mapcars Driver to read
/// this message?") and nothing else.
///
/// It needs no READ_SMS permission and no app-signature hash in the message,
/// which is why it was chosen. A hash would differ between debug builds and
/// Play App Signing's certificate. iOS offers the code above the keyboard by
/// itself (OtpInput's oneTimeCode autofill hint), so this is Android-only.
class SmsCodeListener {
  bool _listening = false;

  /// The 6-digit code from the next SMS the user lets us read. Null if they
  /// decline, it times out (about 5 minutes), there's no code in the message,
  /// or this isn't Android.
  Future<String?> next() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    _listening = true;
    try {
      final res = await SmartAuth.instance.getSmsWithUserConsentApi();
      if (!res.hasData) return null;
      final code = res.requireData.code;
      return code != null && RegExp(r'^\d{6}$').hasMatch(code) ? code : null;
    } catch (e) {
      if (kDebugMode) debugPrint('[sms] user-consent listener failed: $e');
      return null;
    } finally {
      _listening = false;
    }
  }

  void cancel() {
    if (_listening && !kIsWeb && Platform.isAndroid) {
      SmartAuth.instance.removeUserConsentApiListener();
    }
  }
}
