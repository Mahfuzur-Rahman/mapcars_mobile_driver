import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/mc.dart';
import '../../../core/widgets/current_location_map.dart';
import '../../account/providers/driver_trips_provider.dart';
import '../../auth/providers/driver_approval_provider.dart';
import '../../auth/services/driver_auth_service.dart';
import '../providers/dispatch_board_controller.dart';
import '../providers/driver_location_reporting_controller.dart';
import '../providers/trip_realtime_controller.dart';
import '../services/trip_service.dart';
import 'accept_trip.dart';
import 'widgets/request_card.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  /// Starts offline. Going online is a deliberate act that the API only allows
  /// once an admin has approved this driver — never the screen's default.
  /// [_hydrateOnline] then corrects it to whatever the server already thinks.
  bool _online = false;

  /// The server's `isOnline` is only adopted once per mount, so a driver who
  /// then toggles offline isn't flipped back on by a late profile load.
  bool _hydrated = false;

  LatLng? _lastFix;
  BitmapDescriptor? _requestIcon;

  @override
  void initState() {
    super.initState();
    _drawRequestIcon().then((icon) {
      if (mounted) setState(() => _requestIcon = icon);
    });
    _resumeActiveTrip();
  }

  /// A driver whose app was killed mid-job lands here instead of on their
  /// active trip. Re-arm location relaying (otherwise the rider's map freezes
  /// for the rest of the ride) and put them back on the right screen.
  Future<void> _resumeActiveTrip() async {
    Trip? active;
    try {
      final trips = ref.read(tripServiceProvider);
      final direct = await trips.getActive();
      if (direct != null &&
          (direct.status == TripStatus.driverAssigned ||
           direct.status == TripStatus.driverArrived ||
           direct.status == TripStatus.inProgress)) {
        active = direct;
      } else {
        final mine = await trips.mine();
        final live = mine.where((t) =>
            t.status == TripStatus.driverAssigned ||
            t.status == TripStatus.driverArrived ||
            t.status == TripStatus.inProgress).toList();
        if (live.isNotEmpty) {
          final candidate = live.reduce(
              (a, b) => a.createdAtUtc.isAfter(b.createdAtUtc) ? a : b);
          active = await trips.get(candidate.id);
        }
      }
    } catch (_) {
      return; // Offline or the call failed — home is a safe place to land.
    }
    if (active == null || !mounted) return;

    // Re-arm location relaying before navigating away. This screen's
    // `_onLocated` is what normally starts it, and we're about to leave before
    // it ever fires — without this the rider's map freezes for the rest of the
    // ride. Both calls are idempotent.
    final reporting = ref.read(driverLocationReportingProvider);
    reporting.setActiveTrip(active.id);
    reporting.start();
    unawaited(ref.read(tripRealtimeProvider.notifier).attach(active.id));

    final destination = switch (active.status) {
      TripStatus.driverAssigned => '/nav-pickup',
      TripStatus.driverArrived => '/arrived',
      TripStatus.inProgress => '/driving',
      _ => null,
    };
    if (destination != null) context.go(destination, extra: active);
  }

  void _onLocated(LatLng me) {
    _lastFix = me;
    if (_online) {
      ref.read(driverLocationReportingProvider).start();
      final board = ref.read(dispatchBoardProvider.notifier);
      // start() is a no-op once the board is running, so a driver who has
      // moved since going online would otherwise have their board polled
      // against the position they started their shift at.
      board.start(me.latitude, me.longitude);
      board.updatePosition(me.latitude, me.longitude);
    }
  }

  void _ignoreRequest(String tripId) =>
      ref.read(dispatchBoardProvider.notifier).ignore(tripId);

  Future<void> _setOnline(bool value) async {
    // An unapproved driver can't go online — say why instead of firing a call
    // the API will refuse. (Going offline is always allowed.)
    final approval =
        ref.read(driverApprovalProvider).valueOrNull ?? DriverApproval.unknown;
    if (value && !approval.canWork) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(approval.blockedCopy.$2)));
      return;
    }

    final previous = _online;
    setState(() => _online = value);
    final token = ref.read(authTokenProvider);

    if (!value) {
      // Stop pushing first: that DELETEs this driver from the live pool, so the
      // car leaves riders' maps immediately rather than lingering for the 60s
      // staleness window.
      await ref.read(driverLocationReportingProvider).stop();
      await ref.read(dispatchBoardProvider.notifier).stop();
    }

    // Persist availability to the backend. Going online this MUST land before
    // the first location push: the API drops (and evicts) any push from a
    // driver it still has as offline, so starting first would throw the
    // opening fixes away and keep the car off riders' maps.
    if (token != null) {
      try {
        await ref.read(driverAuthServiceProvider).setAvailability(value);
      } catch (e) {
        if (!mounted) return;
        if (value) {
          // If going online failed, revert back to offline
          setState(() => _online = previous);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(e is ApiException
                  ? e.message
                  : "Couldn't update your status. Please try again."),
            ));
          await ref.read(dispatchBoardProvider.notifier).stop();
          return;
        }
        // Going offline: the local stop above already pulled us from the pool.
      }
    }

    if (value) {
      ref.read(driverLocationReportingProvider).start();
      if (_lastFix != null) {
        ref
            .read(dispatchBoardProvider.notifier)
            .start(_lastFix!.latitude, _lastFix!.longitude);
      }
    }
  }

  /// Adopt the server's view of this driver once the profile loads. Without it
  /// the switch reads "Offline" after every app restart while the API still has
  /// the driver online — the driver believes they're working, but nothing is
  /// pushing their position, so riders see no car and no requests arrive.
  void _hydrateOnline(DriverApproval approval) {
    if (_hydrated) return;
    _hydrated = true;
    if (!approval.isOnline || !approval.canWork || _online) return;

    setState(() => _online = true);
    ref.read(driverLocationReportingProvider).start();
    if (_lastFix != null) {
      ref
          .read(dispatchBoardProvider.notifier)
          .start(_lastFix!.latitude, _lastFix!.longitude);
    }
  }

  @override
  void dispose() {
    // Only the requests board is screen-local — location reporting must keep
    // running through an active trip (or any other screen) while online; see
    // `DriverLocationReportingController`.
    ref.read(dispatchBoardProvider.notifier).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(dispatchBoardProvider);
    final approvalAsync = ref.watch(driverApprovalProvider);
    final approval = approvalAsync.valueOrNull ?? DriverApproval.unknown;
    // Runs on the build after the profile arrives — never during build itself.
    if (approvalAsync.hasValue && !_hydrated) {
      final loaded = approvalAsync.requireValue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hydrateOnline(loaded);
      });
    }
    // A driver who isn't approved has no board — the API won't serve them one.
    final focus =
        approval.canWork && board.trips.isNotEmpty ? board.trips.first : null;
    final icon = _requestIcon;
    final markers = icon == null
        ? const <Marker>{}
        : {
            for (final trip in board.trips)
              Marker(
                markerId: MarkerId('request-${trip.id}'),
                position: LatLng(trip.pickupLat, trip.pickupLng),
                icon: icon,
                anchor: const Offset(0.5, 1),
                onTap: () =>
                    ref.read(dispatchBoardProvider.notifier).bringToFront(trip.id),
              ),
          };

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CurrentLocationMap(
              markers: markers,
              onLocated: _onLocated,
            ),
          ),
          // Top: online status pill + avatar
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const McMenuButton(),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
                  decoration: const BoxDecoration(
                    color: Brand.paper,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                    boxShadow: Brand.floatShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        !approval.canWork
                            ? 'Not approved'
                            : (_online ? 'Online' : 'Offline'),
                        style: tw(FontWeight.w900, 14,
                            _online ? Brand.green : Brand.sub),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 54,
                        height: 32,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Switch(
                            value: _online,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Brand.green,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Brand.line,
                            // Null disables the switch outright — an unapproved
                            // driver has nothing to toggle.
                            onChanged: approval.canWork ? _setOnline : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final isOnline = ref.watch(apiHealthProvider).value ?? false;
                            final hasToken = ref.watch(authTokenProvider) != null;
                            final isConnected = isOnline && hasToken;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: const BoxDecoration(
                                color: Brand.paper,
                                borderRadius: BorderRadius.all(Radius.circular(99)),
                                boxShadow: Brand.floatShadow,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isConnected ? Brand.green : Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      isConnected ? 'Connected' : 'Offline',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: tw(FontWeight.w800, 11.5, Brand.sub),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      McCircleButton('search',
                          onTap: () => context.push('/set-route')),
                      const SizedBox(width: 6),
                      McCircleButton('user', onTap: () => context.go('/profile')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (focus == null)
            Align(
              alignment: Alignment.bottomCenter,
              child: McSheet(
                height: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Brand.fill, width: 3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: approval.canWork
                                ? const CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Brand.green),
                                    backgroundColor: Brand.fill,
                                  )
                                : const Icon(Icons.hourglass_top_rounded,
                                    size: 22, color: Brand.sub),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              McTitle(
                                !approval.canWork
                                    ? approval.blockedCopy.$1
                                    : (_online
                                        ? 'Waiting for requests…'
                                        : "You're offline"),
                                size: 18,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                !approval.canWork
                                    ? approval.blockedCopy.$2
                                    : (_online
                                        ? "You'll be notified the moment one comes in"
                                        : 'Go online to start receiving trip requests'),
                                style: tw(FontWeight.w600, 13, Brand.sub),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _EarningsStats(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: approval.canWork
                              ? McGhostButton(
                                  'Earnings',
                                  icon: 'chart',
                                  onTap: () => context.go('/earnings'),
                                )
                              : McGhostButton(
                                  'My documents',
                                  onTap: () => context.go('/documents'),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: approval.canWork
                              ? McGhostButton(
                                  _online ? 'Go offline' : 'Go online',
                                  onTap: () => _setOnline(!_online),
                                )
                              // Approval lands server-side while the app sits
                              // here — let the driver re-check without a restart.
                              : McGhostButton(
                                  'Check status',
                                  onTap: () =>
                                      ref.invalidate(driverApprovalProvider),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // An open request overlays the waiting sheet.
          if (focus != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: RequestCard(
                trip: focus,
                busy: board.busyTripId == focus.id,
                moreCount: board.trips.length - 1,
                onAccept: () => acceptTripAndGo(context, ref, focus),
                onIgnore: () => _ignoreRequest(focus.id),
              ),
            ),
        ],
      ),
    );
  }

  /// Draws the request pickup pin shown on the map for each open request:
  /// green teardrop with a white "person" dot.
  static Future<BitmapDescriptor> _drawRequestIcon() async {
    const w = 96, h = 120;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;
    const green = Color(0xFF16A34A);

    const cx = w / 2.0;
    const headR = 34.0;
    // Teardrop: circle head + triangle tail down to the anchor point.
    paint.color = Colors.black.withValues(alpha: 0.25);
    canvas.drawCircle(const Offset(cx, headR + 10), headR, paint);
    paint.color = green;
    final tail = Path()
      ..moveTo(cx - 20, headR + 32)
      ..lineTo(cx, h - 4)
      ..lineTo(cx + 20, headR + 32)
      ..close();
    canvas.drawPath(tail, paint);
    canvas.drawCircle(const Offset(cx, headR + 6), headR, paint);
    // White "person": head circle + shoulders arc.
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(cx, headR - 6), 10, paint);
    canvas.drawArc(
      Rect.fromCenter(
          center: const Offset(cx, headR + 22), width: 40, height: 34),
      math.pi,
      math.pi,
      true,
      paint,
    );

    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: 2.4,
    );
  }
}

/// The waiting sheet's headline numbers, from the driver's own completed trips
/// (`GET /trips/mine`, shared with the earnings screen). These used to be three
/// hard-coded figures — £62.40 / 5 trips / 3h 12m — shown to every driver.
class _EarningsStats extends ConsumerWidget {
  const _EarningsStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(driverTripsProvider).valueOrNull;
    if (trips == null) {
      return const McCard(
        padding: 14,
        child: Row(
          children: [
            _Stat('—', 'Today'),
            _Stat('—', 'Trips today'),
            _Stat('—', 'This week'),
          ],
        ),
      );
    }

    // Take-home, so the tip (paid 100% to the driver) is added to the base.
    double takeHome(Trip t) => (t.driverEarnings ?? 0) + t.tipAmount;
    DateTime finishedAt(Trip t) => (t.completedAtUtc ?? t.createdAtUtc).toLocal();

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final completed = trips.where((t) => t.status == TripStatus.completed);
    final today = completed.where((t) {
      final at = finishedAt(t);
      return at.year == now.year && at.month == now.month && at.day == now.day;
    }).toList();
    final week = completed.where((t) => finishedAt(t).isAfter(weekAgo));

    final todayPence =
        (today.fold(0.0, (sum, t) => sum + takeHome(t)) * 100).round();
    final weekPence =
        (week.fold(0.0, (sum, t) => sum + takeHome(t)) * 100).round();

    return McCard(
      padding: 14,
      child: Row(
        children: [
          _Stat(formatGbp(todayPence), 'Today'),
          _Stat('${today.length}', 'Trips today'),
          _Stat(formatGbp(weekPence), 'This week'),
        ],
      ),
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
            Text(value, style: tw(FontWeight.w900, 18, Brand.ink)),
            const SizedBox(height: 2),
            Text(label, style: tw(FontWeight.w700, 11.5, Brand.sub)),
          ],
        ),
      );
}
