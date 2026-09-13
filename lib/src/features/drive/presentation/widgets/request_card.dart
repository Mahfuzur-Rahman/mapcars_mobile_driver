import 'package:flutter/material.dart';

import '../../../../core/widgets/countdown.dart';
import '../../../../core/widgets/mc.dart';
import '../../services/trip_service.dart';

/// One open request on the driver's live dispatch board: pickup/drop-off,
/// fare, and Accept / Ignore. Purely presentational — the home screen feeds
/// it state from the [DispatchBoardController] (`dispatch_board_controller.dart`)
/// and handles the button callbacks.
///
/// A request carries a deadline. In the broadcast model it stays open to every
/// nearby driver until someone accepts, but not forever: it lapses if nobody
/// does, so the card counts down to that and stops offering Accept when the
/// clock runs out. The countdown is what creates the reason to decide now — a
/// card with no visible deadline is one a driver can put off looking at.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.trip,
    required this.busy,
    required this.moreCount,
    required this.onAccept,
    required this.onIgnore,
    this.expired = false,
    this.onExpired,
  });

  final Trip trip;
  final bool busy;

  /// How many other open requests are also on the board right now.
  final int moreCount;

  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  /// The request has lapsed and is on its way off the board. Shown for a beat
  /// rather than removed outright, so a driver reaching for Accept sees why it
  /// went instead of watching the next card jump up under their thumb.
  final bool expired;

  /// Fired once this card's own countdown reaches zero. The fallback for a
  /// driver whose socket is down or whose app was backgrounded through the
  /// server's `tripExpired` push — without it, a card can sit there offering
  /// Accept on a job that is already gone.
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) => ExpiryCountdown(
        deadline: trip.expiresAtUtc,
        builder: (context, left) {
          // Either signal means gone: the board was told (server push), or this
          // card watched its own clock run out. Treating the local clock as
          // enough is what keeps the one-shot preview screen honest — it has no
          // board behind it to be told anything.
          final lapsed = expired ||
              (trip.expiresAtUtc != null && left == Duration.zero);

          if (lapsed && !expired && onExpired != null) {
            // Never mutate board state from inside a build. The controller
            // ignores a repeat for a request it is already expiring, so firing
            // on each of the next few frames is harmless.
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onExpired!.call());
          }

          return _card(context, left, lapsed);
        },
      );

  Widget _card(BuildContext context, Duration left, bool lapsed) {
    final fare = trip.fareAmount ?? 0;
    final miles = trip.distanceMiles ?? 0;

    return McSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              McTitle(
                lapsed ? 'Request expired' : 'New trip request',
                size: 19,
                color: lapsed ? Brand.sub : Brand.ink,
              ),
              const Spacer(),
              _CountdownChip(
                left: left,
                lapsed: lapsed,
                hasDeadline: trip.expiresAtUtc != null,
              ),
              if (moreCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Brand.fill,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '+$moreCount more',
                    style: tw(FontWeight.w900, 13, Brand.sub),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _Leg(color: Brand.green, label: 'Pickup', address: trip.pickupAddress),
          const Padding(
            padding: EdgeInsets.only(left: 5),
            child: SizedBox(
              height: 18,
              child: VerticalDivider(width: 1, thickness: 1.5, color: Brand.line),
            ),
          ),
          _Leg(color: Brand.blue, label: 'Drop-off', address: trip.dropoffAddress),
          const SizedBox(height: 14),
          McCard(
            padding: 14,
            child: Row(
              children: [
                _Stat('£${fare.toStringAsFixed(2)}', 'Fare'),
                _Stat('${miles.toStringAsFixed(1)} mi', 'Distance'),
                if (trip.tier != null && trip.tier!.isNotEmpty)
                  _Stat(_titleCase(trip.tier!), 'Tier'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: McGhostButton(
                  lapsed ? 'Dismiss' : 'Ignore',
                  onTap: busy ? null : onIgnore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                // Disabling Accept here is a courtesy, not the guard: the API
                // refuses a lapsed request on its own clock, so a stale card or
                // a skewed phone can't take a job that has gone.
                child: lapsed
                    ? const McButton('Expired', kind: BtnKind.green, onTap: null)
                    : McButton(
                        busy ? 'Accepting…' : 'Accept',
                        kind: BtnKind.green,
                        onTap: busy ? null : onAccept,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// How long this request has left. Neutral while there is time, amber under a
/// minute — the point where "there is a job here" becomes "decide now".
///
/// Takes an already-computed duration: the card above owns the single ticking
/// subtree, so the clock and everything else on the card can never disagree
/// about whether the request has run out.
class _CountdownChip extends StatelessWidget {
  const _CountdownChip({
    required this.left,
    required this.lapsed,
    required this.hasDeadline,
  });

  final Duration left;
  final bool lapsed;

  /// False for a trip booked before deadlines existed.
  final bool hasDeadline;

  @override
  Widget build(BuildContext context) {
    if (lapsed) return _chip('Expired', Brand.faint, Brand.fill);

    // Nothing to count down to. Show nothing rather than a permanent 0:00,
    // which reads as a job that expired the moment it arrived.
    if (!hasDeadline) return const SizedBox.shrink();

    final urgent = left.inSeconds <= 60;
    return _chip(
      formatCountdown(left),
      urgent ? Brand.star : Brand.sub,
      urgent ? Brand.star.withValues(alpha: 0.12) : Brand.fill,
    );
  }

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: tw(FontWeight.w900, 13, fg)),
      );
}

class _Leg extends StatelessWidget {
  const _Leg({required this.color, required this.label, required this.address});
  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: tw(FontWeight.w700, 11.5, Brand.sub)),
              Text(
                address.isEmpty ? '—' : address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tw(FontWeight.w800, 14.5, Brand.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: tw(FontWeight.w900, 17, Brand.ink)),
            const SizedBox(height: 2),
            Text(label, style: tw(FontWeight.w700, 11.5, Brand.sub)),
          ],
        ),
      );
}
