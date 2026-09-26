import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
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

  /// False only for [unknown] — the API hasn't answered yet (or couldn't be
  /// reached), which is not the same as being told "not approved".
  bool get isKnown => status != _unknownStatus;

  /// Headline + body for the "you can't work yet" sheet. Mirrors the API's
  /// `DriverApproval.BlockedMessage` so both sides say the same thing.
  (String title, String body) get blockedCopy => switch (status) {
        _unknownStatus => (
            'Checking your account',
            'Confirming your approval with Mapcars. If this doesn’t clear, check your connection and tap Check status.',
          ),
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

  static const _unknownStatus = 'Unknown';

  /// Whenever the API's answer isn't in hand — no session, still loading, or
  /// the profile call failed. Fails **closed**: this used to be
  /// `status: 'Approved'` (so the offline demo session could reach the board),
  /// which meant every screen treated "don't know yet" as "cleared to work".
  /// Approval is only ever what `GET /auth/drivers/me` says it is.
  static const unknown = DriverApproval(status: _unknownStatus, isOnline: false);
}

/// Loads the driver's approval status. No session → [DriverApproval.unknown];
/// otherwise it is exactly what the API's driver profile reports.
final driverApprovalProvider = FutureProvider<DriverApproval>((ref) async {
  final token = ref.watch(authTokenProvider);
  if (token == null) return DriverApproval.unknown;

  final profile = await ref.read(driverAuthServiceProvider).getProfile();
  return DriverApproval(
    status: profile.status,
    isOnline: profile.isOnline,
    acceptsCash: profile.acceptsCash,
    acceptsCard: profile.acceptsCard,
  );
});
