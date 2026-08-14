/// Hard-coded demo driver so the app runs fully offline — no API / database
/// needed — until the real auth endpoints are wired up.
///
/// Enter [phoneDisplay] on the verify screen; the OTP is [otp] (pre-filled /
/// shown on-screen). The auth flow detects the demo number and short-circuits
/// to a local session instead of calling the API. Swap back to the API path
/// (see [AuthNotifier]) once the backend is reachable.
class DemoCredentials {
  const DemoCredentials._();

  /// Canonical E.164 form the app stores / compares against.
  static const phone = '+447700900000';

  /// What the user types after the +44 prefix.
  static const phoneDisplay = '7700 900000';

  /// The accepted demo verification code.
  static const otp = '000000';

  static const userId = 'demo-driver';
  static const fullName = 'Demo Driver';
  static const email = 'demo.driver@mapcars.co.uk';
  static const password = 'Driver@1234';

  /// A long-lived fake token so the persisted session survives restarts.
  static const token = 'demo-token-driver';
  static const sessionMinutes = 60 * 24 * 30; // 30 days
}

/// True when [phone] (any spacing / hyphenation) is the demo number.
bool isDemoPhone(String phone) =>
    phone.replaceAll(' ', '').replaceAll('-', '') == DemoCredentials.phone;
