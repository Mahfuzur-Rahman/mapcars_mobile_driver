/// Where a tapped notification should take the driver — decided from its data
/// payload alone, so the rule can be tested without Firebase, a router or a
/// session. Carrying it out is [PushTapNavigator]'s job.
///
/// Every push the API sends a driver has a `type`; the ids it needs ride
/// alongside. Anything unrecognised or incomplete resolves to [JustOpenApp]:
/// a tap must never crash, and never land on a route with nothing behind it.
sealed class PushTap {
  const PushTap();
}

/// `tripAvailable` — a new request. Opens the board, not the trip: the job may
/// already have been taken or have expired, and the board is what knows that.
final class OpenRequestsBoard extends PushTap {
  const OpenRequestsBoard(this.tripId);
  final String tripId;
}

/// `tripStatus` with a cancelled status — the job the driver was on is off.
final class OpenCancelledTrip extends PushTap {
  const OpenCancelledTrip(this.tripId);
  final String tripId;
}

/// `messageReceived` — the customer wrote in this trip's chat.
final class OpenTripChat extends PushTap {
  const OpenTripChat(this.tripId);
  final String tripId;
}

/// `tier_appeal_decision` — an admin ruled on a vehicle-tier appeal.
final class OpenTierAppeal extends PushTap {
  const OpenTierAppeal(this.appealId);
  final String appealId;
}

/// Nothing to route to — bringing the app forward is the whole response.
final class JustOpenApp extends PushTap {
  const JustOpenApp();
}

/// Payload → destination. Pure: no I/O, never throws.
PushTap pushTapFor(Map<String, dynamic> data) {
  // FCM data values are strings on the wire, but a local notification's
  // payload is our own JSON — so read loosely and treat blank as absent.
  String? read(String key) {
    final v = data[key]?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  // Normalised so a casing or snake/camel drift on the server
  // ("tierAppealDecision" vs "tier_appeal_decision") still routes rather than
  // degrading to JustOpenApp.
  final type = read('type')?.toLowerCase().replaceAll('_', '');
  final tripId = read('tripId');

  switch (type) {
    case 'tripavailable':
      return tripId == null ? const JustOpenApp() : OpenRequestsBoard(tripId);
    case 'tripstatus':
      // Only a cancellation is worth a push to the driver — every other status
      // change is their own action. Any other status just opens the app.
      final status = read('status')?.toLowerCase() ?? '';
      if (tripId == null || !status.startsWith('cancelled')) {
        return const JustOpenApp();
      }
      return OpenCancelledTrip(tripId);
    case 'messagereceived':
      return tripId == null ? const JustOpenApp() : OpenTripChat(tripId);
    case 'tierappealdecision':
      final appealId = read('appealId');
      return appealId == null ? const JustOpenApp() : OpenTierAppeal(appealId);
    default:
      return const JustOpenApp();
  }
}

/// Holds a tap until the app can act on it, then hands it to [open].
///
/// A cold start is the dangerous case: the tap is known before the splash has
/// restored the session, and navigating then would race the restore (and the
/// splash's own "go home"). So nothing is opened until [sessionReady] — the
/// splash calls it once the session is settled — and only the latest held tap
/// survives, since that is the one the driver just touched.
///
/// Signed-out taps are dropped: the app is open, which is all a driver without
/// a session can be given — every destination here is behind sign-in.
class PushTapDispatcher {
  PushTapDispatcher({required this.isSignedIn, required this.open});

  final bool Function() isSignedIn;

  /// Carries a tap out. Resolves true if it navigated somewhere.
  final Future<bool> Function(PushTap tap) open;

  bool _ready = false;
  PushTap? _held;

  /// A notification was tapped (or launched the app).
  Future<bool> tap(PushTap tap) async {
    if (!_ready) {
      _held = tap;
      return false;
    }
    return _open(tap);
  }

  /// The session is restored and the router is up. Opens the held tap, if
  /// any; resolves true when that navigated, so the splash knows not to send
  /// the driver home over the top of it. Idempotent.
  Future<bool> sessionReady() async {
    if (_ready) return false;
    _ready = true;
    final held = _held;
    _held = null;
    return held == null ? false : _open(held);
  }

  Future<bool> _open(PushTap tap) async {
    if (tap is JustOpenApp || !isSignedIn()) return false;
    try {
      return await open(tap);
    } catch (_) {
      return false; // a failed route must never surface as a crash
    }
  }
}
