import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/current_location_map.dart';
import '../../../core/widgets/mc.dart';
import '../providers/dispatch_board_controller.dart';
import '../services/trip_service.dart';
import 'accept_trip.dart';
import 'widgets/request_card.dart';

/// The "incoming request" moment as its own route.
///
/// In the live flow this is an overlay on `DriverHomeScreen`, fed by
/// [DispatchBoardController]; this route is how the menu and the screen index
/// step through the same moment. It shows the driver's **real** open requests —
/// the live board while they're online, otherwise a one-shot fetch of what's
/// open near them — and Accept is the real accept. It used to render a
/// hard-coded demo request that was indistinguishable from a real job.
class RequestPreviewScreen extends ConsumerStatefulWidget {
  const RequestPreviewScreen({super.key});

  @override
  ConsumerState<RequestPreviewScreen> createState() =>
      _RequestPreviewScreenState();
}

class _RequestPreviewScreenState extends ConsumerState<RequestPreviewScreen> {
  static const _locationService = LocationService();

  List<Trip> _open = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = ref.read(tripServiceProvider);
      List<Trip> open;
      try {
        final pos = await _locationService.currentPosition();
        open = await trips.availableNearby(lat: pos.latitude, lng: pos.longitude);
      } on LocationException {
        // No fix (permission denied or GPS off) — the unfiltered board is still
        // real data, just not distance-sorted.
        open = await trips.available();
      }
      if (!mounted) return;
      // A refresh must not undo an Ignore — the board controller is the one
      // that remembers what this driver has already turned down.
      final board = ref.read(dispatchBoardProvider.notifier);
      setState(() {
        _open = open.where((t) => !board.isIgnored(t.id)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : "Couldn't load open requests.";
        _loading = false;
      });
    }
  }

  /// Waves a request away, exactly as the home board does — the controller owns
  /// the ignored set, this screen just drops it from its own one-shot list too.
  void _ignore(String tripId) {
    ref.read(dispatchBoardProvider.notifier).ignore(tripId);
    setState(() => _open = _open.where((t) => t.id != tripId).toList());
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(dispatchBoardProvider);
    // The live board wins whenever the driver is online (it's kept current by
    // SignalR); the one-shot fetch is what fills this screen when they're not.
    final open = board.trips.isNotEmpty ? board.trips : _open;
    final focus = open.isEmpty ? null : open.first;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CurrentLocationMap()),
          const Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: McFloatingNav(showBack: false),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: focus != null
                ? RequestCard(
                    trip: focus,
                    busy: board.busyTripId == focus.id,
                    moreCount: open.length - 1,
                    onAccept: () => acceptTripAndGo(context, ref, focus),
                    onIgnore: () => _ignore(focus.id),
                  )
                : _NoRequests(
                    loading: _loading,
                    error: _error,
                    onRefresh: _load,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the driver has no open requests — the honest counterpart to the
/// demo card this screen used to invent.
class _NoRequests extends StatelessWidget {
  const _NoRequests({
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final title = loading
        ? 'Checking for requests…'
        : (error != null ? "Couldn't load requests" : 'No open requests');
    final body = loading
        ? 'Looking for trip requests near you.'
        : (error ??
            'Nothing is waiting near you right now. Go online from Home and '
                'new requests will appear the moment they come in.');

    return McSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Brand.green),
                          backgroundColor: Brand.fill,
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          color: Brand.fill,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Ico('bell', size: 20, color: Brand.sub),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(child: McTitle(title, size: 18)),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: tw(FontWeight.w600, 13, Brand.sub)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: McGhostButton('Refresh',
                    onTap: loading ? null : onRefresh),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: McButton('Go to home',
                    icon: 'home', onTap: () => context.go('/home')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
