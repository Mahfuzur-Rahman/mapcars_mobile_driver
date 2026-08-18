import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/mc.dart';
import '../providers/trip_realtime_controller.dart';
import '../services/nav_handoff.dart';
import '../services/trip_service.dart';
import 'widgets/live_route_map.dart';

/// Leg 1 of the active trip: driving to the rider. Shows the real route to the
/// pickup with a live ETA, hands turn-by-turn off to the driver's navigation app
/// of choice, and marks arrival when they get there.
class NavPickupScreen extends ConsumerStatefulWidget {
  const NavPickupScreen({super.key, required this.trip});

  /// The accepted trip. Always a real one — `TripGate` either passes the trip
  /// the driver arrived with or resolves their active job from the API before
  /// this screen builds.
  final Trip trip;

  @override
  ConsumerState<NavPickupScreen> createState() => _NavPickupScreenState();
}

class _NavPickupScreenState extends ConsumerState<NavPickupScreen> {
  bool _busy = false;
  RouteProgress? _progress;

  /// Marks arrival at the pickup. This used to be what the "Navigate" button
  /// did, which meant a driver who only wanted directions was reported as
  /// already at the kerb — arrival is now its own explicit action.
  Future<void> _confirmArrival() async {
    if (_busy) return;
    final trip = widget.trip;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(tripServiceProvider).arrive(trip.id);
      if (!mounted) return;
      context.go('/arrived', extra: updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't confirm arrival. Please try again."),
        ));
    }
  }

  Future<void> _navigate() async {
    final trip = widget.trip;
    await NavHandoff.start(
      context,
      lat: trip.pickupLat,
      lng: trip.pickupLng,
      label: trip.pickupAddress,
    );
  }

  void _callRider() {
    // The API deliberately doesn't expose the rider's number (see TripRiderInfo)
    // — until a masked-call service is wired up, in-app chat is the channel.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Use Message to reach your rider.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final progress = _progress;

    ref.listen<TripRealtimeState>(tripRealtimeProvider, (prev, next) {
      if (next.cancelledTrip?.id == trip.id) {
        showTripCancelledDialog(context, ref, next.cancelledTrip!);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LiveRouteMap(
              destination: LatLng(trip.pickupLat, trip.pickupLng),
              destinationLabel: trip.pickupAddress,
              isPickup: true,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            ),
          ),
          Positioned(
            top: 50,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EtaBanner(
                  eta: progress?.etaLabel ?? '—',
                  distance: progress?.distanceLabel ?? 'Finding route…',
                  caption: 'to pickup',
                  colour: Brand.green,
                ),
                const SizedBox(height: 10),
                const Align(alignment: Alignment.centerRight, child: McMenuButton()),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Brand.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pickup · ${trip.rider?.name ?? 'your rider'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tw(FontWeight.w900, 15, Brand.ink),
                        ),
                      ),
                      if (progress != null)
                        Text(progress.etaLabel,
                            style: tw(FontWeight.w800, 14, Brand.green)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(trip.pickupAddress,
                      style: tw(FontWeight.w700, 13.5, Brand.sub)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _SquareButton(icon: 'phone', onTap: _callRider),
                      const SizedBox(width: 10),
                      _SquareButton(
                          icon: 'msg', onTap: () => context.push('/chat', extra: trip)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: McGhostButton(
                          'Navigate',
                          icon: 'nav',
                          height: 50,
                          onTap: _navigate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  McButton(
                    _busy ? 'Confirming…' : "I've arrived",
                    icon: 'check',
                    kind: BtnKind.green,
                    onTap: _busy ? null : _confirmArrival,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, this.onTap});
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Brand.fill,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(child: Ico(icon, size: 22, color: Brand.ink)),
        ),
      );
}

/// Live "how far, how long" banner. Replaces the old fake turn-by-turn banner —
/// the actual manoeuvre instructions come from the navigation app the driver
/// hands off to, so promising them here would have been a lie either way.
class _EtaBanner extends StatelessWidget {
  const _EtaBanner({
    required this.eta,
    required this.distance,
    required this.caption,
    required this.colour,
  });

  final String eta;
  final String distance;
  final String caption;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5216202E),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Ico('nav', size: 30, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(eta,
                    style: tw(FontWeight.w900, 22, Colors.white)
                        .copyWith(height: 1)),
                const SizedBox(height: 3),
                Text('$distance · $caption',
                    style: tw(FontWeight.w700, 13.5,
                        Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
