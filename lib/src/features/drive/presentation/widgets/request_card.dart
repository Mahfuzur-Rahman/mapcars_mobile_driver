import 'package:flutter/material.dart';

import '../../../../core/widgets/mc.dart';
import '../../services/trip_service.dart';

/// One open request on the driver's live dispatch board: pickup/drop-off,
/// fare, and Accept / Ignore. Purely presentational — the home screen feeds
/// it state from the [DispatchBoardController] (`dispatch_board_controller.dart`)
/// and handles the button callbacks. Unlike the old sequential-offer card,
/// there's no per-request countdown: in the broadcast model a request stays
/// open (and visible to every nearby driver) until someone accepts it.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.trip,
    required this.busy,
    required this.moreCount,
    required this.onAccept,
    required this.onIgnore,
  });

  final Trip trip;
  final bool busy;

  /// How many other open requests are also on the board right now.
  final int moreCount;

  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final fare = trip.fareAmount ?? 0;
    final miles = trip.distanceMiles ?? 0;

    return McSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const McTitle('New trip request', size: 19),
              const Spacer(),
              if (moreCount > 0)
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
                child: McGhostButton('Ignore', onTap: busy ? null : onIgnore),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: McButton(
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
