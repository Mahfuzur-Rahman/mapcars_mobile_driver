import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/location/location_service.dart';
import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../models/directions_result.dart';
import '../models/place.dart';
import '../services/maps_service.dart';

/// Shows the driving route from the driver's current location to [destination],
/// drawn on a Google map with distance + ETA — the "directions like Google Maps"
/// view.
class RoutePreviewScreen extends ConsumerStatefulWidget {
  const RoutePreviewScreen({super.key, required this.destination});
  final Place destination;

  @override
  ConsumerState<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends ConsumerState<RoutePreviewScreen> {
  static const _locationService = LocationService();

  GoogleMapController? _controller;
  LatLng? _origin;
  DirectionsResult? _route;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await _locationService.currentPosition();
      final origin = LatLng(pos.latitude, pos.longitude);
      final dest = LatLng(widget.destination.lat, widget.destination.lng);
      final route = await ref
          .read(googleMapsServiceProvider)
          .directions(origin: origin, destination: dest);
      if (!mounted) return;
      setState(() {
        _origin = origin;
        _route = route;
        _loading = false;
      });
      _fitBounds();
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on MapsServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't build the route. Please try again.";
        _loading = false;
      });
    }
  }

  Future<void> _fitBounds() async {
    final route = _route;
    final c = _controller;
    if (route == null || c == null) return;
    await c.animateCamera(CameraUpdate.newLatLngBounds(route.bounds, 64));
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    final destLatLng = LatLng(dest.lat, dest.lng);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: destLatLng, zoom: 13),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              markers: {
                if (_origin != null)
                  Marker(
                    markerId: const MarkerId('origin'),
                    position: _origin!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
                    infoWindow: const InfoWindow(title: 'Current location'),
                  ),
                Marker(
                  markerId: const MarkerId('destination'),
                  position: destLatLng,
                  infoWindow: InfoWindow(title: dest.label, snippet: dest.address),
                ),
              },
              polylines: {
                if (_route != null)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: _route!.points,
                    color: Brand.blue,
                    width: 5,
                  ),
              },
              onMapCreated: (c) {
                _controller = c;
                _fitBounds();
              },
            ),
          ),
          Positioned(
            top: 58,
            left: 16,
            right: 16,
            child: McFloatingNav(
              showHome: false,
              onBack: () => backOr(context, '/set-route'),
            ),
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(color: Brand.bg, child: _Loading()),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              child: _error != null
                  ? _RouteError(message: _error!, onRetry: _load)
                  : _RouteSummary(destination: dest, route: _route),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.destination, this.route});
  final Place destination;
  final DirectionsResult? route;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Brand.blue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Ico('pin', size: 18, color: Brand.blue)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tw(FontWeight.w900, 17)),
                  if (destination.address.isNotEmpty)
                    Text(destination.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tw(FontWeight.w600, 12.5, Brand.sub)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (route != null)
          Row(
            children: [
              _Metric(icon: 'clock', value: route!.durationText, label: 'Duration'),
              const SizedBox(width: 10),
              _Metric(icon: 'pin', value: route!.distanceText, label: 'Distance'),
            ],
          ),
        const SizedBox(height: 16),
        McButton(
          'Done',
          icon: 'check',
          onTap: () => backOr(context, '/home'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Brand.fill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Ico(icon, size: 18, color: Brand.sub),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: tw(FontWeight.w900, 15)),
                Text(label, style: tw(FontWeight.w700, 11, Brand.sub)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteError extends StatelessWidget {
  const _RouteError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message,
            textAlign: TextAlign.center,
            style: tw(FontWeight.w700, 14, Brand.sub)),
        const SizedBox(height: 16),
        McButton('Try again', icon: 'clock', onTap: onRetry),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Brand.blue),
        ),
      ),
    );
  }
}
