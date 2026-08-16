import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/mc.dart';
import '../../providers/active_trip_provider.dart';
import '../../providers/driver_location_reporting_controller.dart';
import '../../providers/trip_realtime_controller.dart';
import '../../services/trip_service.dart';

/// Which trip a screen behind the gate is about.
enum TripGateScope {
  /// The job the driver is on right now (`/nav-pickup`, `/arrived`,
  /// `/driving`, `/chat`).
  active,

  /// The job they just finished (`/trip-complete`).
  lastCompleted,
}

/// Guarantees a trip screen a **real** [Trip] before it builds.
///
/// Every trip screen used to take a nullable trip and quietly render invented
/// content when it got null — a fake rider, a fake address, a fake fare, and a
/// decorative map with no live position. Null now means one of two honest
/// things instead: we're still asking the API, or the driver genuinely has no
/// such trip.
///
/// When the gate resolves the trip itself (rather than receiving it through
/// `extra`), it also re-arms the realtime attach and the location-push trip id,
/// so a screen entered from the menu or a deep link still gets cancellations,
/// chat, and rider-visible position updates.
class TripGate extends ConsumerStatefulWidget {
  const TripGate({
    super.key,
    required this.builder,
    this.trip,
    this.scope = TripGateScope.active,
  });

  /// The trip the caller already has, when it has one — the normal in-flow case.
  final Trip? trip;

  final TripGateScope scope;
  final Widget Function(Trip trip) builder;

  @override
  ConsumerState<TripGate> createState() => _TripGateState();
}

class _TripGateState extends ConsumerState<TripGate> {
  String? _armedTripId;

  ProviderListenable<AsyncValue<Trip?>> get _provider =>
      widget.scope == TripGateScope.active
          ? activeTripProvider
          : lastCompletedTripProvider;

  /// Both calls are idempotent, and are what the home screen's resume path does
  /// after picking an active trip back up.
  void _arm(Trip trip) {
    if (widget.scope != TripGateScope.active || _armedTripId == trip.id) return;
    _armedTripId = trip.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(driverLocationReportingProvider).setActiveTrip(trip.id);
      unawaited(ref.read(tripRealtimeProvider.notifier).attach(trip.id));
    });
  }

  void _retry() => ref.invalidate(widget.scope == TripGateScope.active
      ? activeTripProvider
      : lastCompletedTripProvider);

  @override
  Widget build(BuildContext context) {
    final passed = widget.trip;
    if (passed != null) return widget.builder(passed);

    return ref.watch(_provider).when(
          loading: () => const _GateMessage(
            icon: 'nav',
            title: 'Loading your trip…',
            body: 'Checking with Mapcars for the job you’re on.',
            busy: true,
          ),
          error: (_, __) => _GateMessage(
            icon: 'x',
            title: "Couldn't load your trip",
            body: 'Check your connection and try again.',
            onRetry: _retry,
          ),
          data: (trip) {
            if (trip == null) return _empty();
            _arm(trip);
            return widget.builder(trip);
          },
        );
  }

  Widget _empty() => switch (widget.scope) {
        TripGateScope.active => const _GateMessage(
            icon: 'car',
            title: 'No active trip',
            body: 'You’re not on a trip right now. Go online from Home and '
                'requests will appear there.',
          ),
        TripGateScope.lastCompleted => const _GateMessage(
            icon: 'check',
            title: 'No completed trips yet',
            body: 'Your earnings summary shows here after you finish a trip.',
          ),
      };
}

/// The gate's three non-trip states: waiting on the API, failed, or nothing to
/// show. Deliberately plain — this must never be mistakable for a live trip.
class _GateMessage extends StatelessWidget {
  const _GateMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.busy = false,
    this.onRetry,
  });

  final String icon;
  final String title;
  final String body;
  final bool busy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const McNavHeader(showBack: false),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: busy
                            ? const Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Brand.blue),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: const BoxDecoration(
                                  color: Brand.fill,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Ico(icon, size: 28, color: Brand.sub),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      McTitle(title, size: 20, align: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: tw(FontWeight.w600, 14, Brand.sub),
                      ),
                    ],
                  ),
                ),
              ),
              if (onRetry != null) ...[
                McGhostButton('Try again', onTap: onRetry),
                const SizedBox(height: 10),
              ],
              McButton('Go to home',
                  icon: 'home', onTap: () => context.go('/home')),
            ],
          ),
        ),
      ),
    );
  }
}
