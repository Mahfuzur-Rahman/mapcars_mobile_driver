import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../demo_credentials.dart';
import '../services/driver_auth_service.dart';

/// Whether this driver is cleared to work, straight from the API's driver
/// profile (`GET /auth/drivers/me` → `status`).
///
/// A driver may only go online, see the requests board and take trips once an
/// admin has reviewed their documents and approved them. The API enforces this
/// on every relevant endpoint — this is purely so the app can *show* the right
/// thing (a pending banner instead of a dead online switch) rather than letting
/// the driver toggle into an error.
class DriverApproval {
  const DriverApproval({
    required this.status,
    required this.isOnline,
    this.acceptsCash = true,
    this.acceptsCard = false,
  });

  /// "PendingApproval" | "Approved" | "Suspended" | "Rejected".
  final String status;

  /// What the server thinks — the driver may have gone online on another device.
  final bool isOnline;

  /// Which fares this driver can be offered, resolved by the API (the platform
  /// setting narrowed by any per-driver override). Carried here rather than
  /// fetched separately because this provider already loads the whole profile
  /// and throws most of it away.
  final bool acceptsCash;
  final bool acceptsCard;

  /// An admin has restricted this driver to one kind of fare. Worth saying out
  /// loud: their board is thinner than they expect, and an unexplained quiet
  /// board reads as a broken app, or as dispatch freezing them out.
  bool get isPaymentRestricted => !(acceptsCash && acceptsCard);

  /// One line explaining the restriction, or null when there is nothing to say.
  String? get paymentRestrictionNote {
    if (!isPaymentRestricted) return null;
    if (acceptsCard && !acceptsCash) {
      return "You're set to card payments only, so cash requests aren't shown to you.";
    }
    if (acceptsCash && !acceptsCard) {
      return "You're set to cash only, so card requests aren't shown to you.";
    }
    return 'No payment methods are enabled for your account — contact Mapcars support.';
  }

  bool get canWork => status == 'Approved';

  /// Headline + body for the "you can't work yet" sheet. Mirrors the API's
  /// `DriverApproval.BlockedMessage` so both sides say the same thing.
  (String title, String body) get blockedCopy => switch (status) {
        'Suspended' => (
            'Account suspended',
            'Your account is suspended, so you can’t go online. Contact Mapcars support.',
          ),
        'Rejected' => (
            'Application not approved',
            'Your application wasn’t approved, so you can’t go online. Contact Mapcars support.',
          ),
        _ => (
            'Awaiting approval',
            'An admin is reviewing your documents. You’ll be able to go online and receive trip requests as soon as you’re approved.',
          ),
      };

  /// Used for the offline demo session and whenever the status isn't known yet
  /// — the app stays out of the way and lets the API have the final say.
  static const unknown = DriverApproval(status: 'Approved', isOnline: false);
}

/// Loads the driver's approval status. Null token (or the offline demo session,
/// which has no real account behind it) → [DriverApproval.unknown], so the
/// prototype path keeps working untouched.
final driverApprovalProvider = FutureProvider<DriverApproval>((ref) async {
  final token = ref.watch(authTokenProvider);
  if (token == null || token == DemoCredentials.token) return DriverApproval.unknown;

  final profile = await ref.read(driverAuthServiceProvider).getProfile();
  return DriverApproval(
    status: profile.status,
    isOnline: profile.isOnline,
    acceptsCash: profile.acceptsCash,
    acceptsCard: profile.acceptsCard,
  );
});
