import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/mc.dart';
import '../providers/driver_location_reporting_controller.dart';
import '../providers/trip_realtime_controller.dart';
import '../services/nav_handoff.dart';
import '../services/trip_service.dart';
import 'widgets/live_route_map.dart';

/// Leg 2: rider on board, driving to the destination. Live route, live ETA, and
/// the cash to collect on arrival.
class DrivingScreen extends ConsumerStatefulWidget {
  const DrivingScreen({super.key, required this.trip});

  /// The in-progress trip — always a real one, supplied or resolved by
  /// `TripGate`.
  final Trip trip;

  @override
  ConsumerState<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends ConsumerState<DrivingScreen> {
  bool _busy = false;
  RouteProgress? _progress;

  Future<void> _complete() async {
    if (_busy) return;
    final trip = widget.trip;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(tripServiceProvider).complete(trip.id);
      ref.read(driverLocationReportingProvider).setActiveTrip(null);
      unawaited(ref.read(tripRealtimeProvider.notifier).detach());
      if (!mounted) return;
      context.go('/trip-complete', extra: updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't complete the trip. Please try again."),
        ));
    }
  }

  Future<void> _navigate() async {
    final trip = widget.trip;
    await NavHandoff.start(
      context,
      lat: trip.dropoffLat,
      lng: trip.dropoffLng,
      label: trip.dropoffAddress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final progress = _progress;
    final fare = trip.fareAmount;
    final showCash = trip.isCash;

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
              destination: LatLng(trip.dropoffLat, trip.dropoffLng),
              destinationLabel: trip.dropoffAddress,
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
                  onNavigate: _navigate,
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerRight,
                  child: McMenuButton(),
                ),
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
                        decoration: BoxDecoration(
                          color: Brand.blue,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            trip.dropoffAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tw(FontWeight.w900, 15, Brand.ink)),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 80,
                          height: 6,
                          color: Brand.fill,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            // Real progress along the route, not a fixed 58%.
                            widthFactor: progress?.fraction ?? 0.0,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Brand.blue, Brand.green],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (showCash) ...[
                    _CashCollectBanner(amount: trip.cashDue),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      _StatCard(
                        value: progress?.etaLabel ?? '—',
                        sub: progress == null
                            ? 'arrival'
                            : 'arrival ${progress.arrivalLabel}',
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                          value: progress?.distanceLabel ?? '—',
                          sub: 'remaining'),
                      const SizedBox(width: 10),
                      _StatCard(
                          value:
                              fare != null ? '£${fare.toStringAsFixed(2)}' : '—',
                          sub: 'fare',
                          valueColor: Brand.green),
                    ],
                  ),
                  const SizedBox(height: 14),
                  McButton(
                    _busy ? 'Completing…' : 'Complete trip',
                    icon: 'check',
                    kind: BtnKind.green,
                    onTap: _busy ? null : _complete,
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

/// Shown during a cash trip so the driver knows to collect the fare (+ tip) in
/// person at drop-off before completing — no card charge happens for cash.
class _CashCollectBanner extends StatelessWidget {
  const _CashCollectBanner({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Brand.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Ico('cash', size: 20, color: Brand.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Collect from rider in cash',
                style: tw(FontWeight.w700, 13, Brand.ink)),
          ),
          Text('£${amount.toStringAsFixed(2)}',
              style: tw(FontWeight.w900, 16, Brand.green)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.value, required this.sub, this.valueColor = Brand.ink});
  final String value;
  final String sub;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
        child: McCard(
          padding: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tw(FontWeight.w900, 17, valueColor)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tw(FontWeight.w700, 11, Brand.sub)),
            ],
          ),
        ),
      );
}

/// Live distance/ETA to the drop-off, with a shortcut into the driver's own
/// navigation app for the actual turn-by-turn.
class _EtaBanner extends StatelessWidget {
  const _EtaBanner({
    required this.eta,
    required this.distance,
    this.onNavigate,
  });

  final String eta;
  final String distance;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Brand.blue,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(eta,
                    style: tw(FontWeight.w900, 22, Colors.white)
                        .copyWith(height: 1)),
                const SizedBox(height: 3),
                Text('$distance · to drop-off',
                    style: tw(FontWeight.w700, 13.5,
                        Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
          if (onNavigate != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNavigate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Ico('nav', size: 17, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Navigate',
                        style: tw(FontWeight.w800, 12.5, Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
