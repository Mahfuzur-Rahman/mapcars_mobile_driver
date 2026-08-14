import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/location_service.dart';
import '../theme/brand.dart';

/// A live Google map centered on the device's current location, with the blue
/// "my location" dot and re-center button. Handles the permission / GPS-off /
/// loading states in-line so screens can just drop it in as a full-bleed layer.
///
/// Requires native config: location permissions + a Maps SDK for Android key in
/// `android/local.properties` (MAPS_API_KEY). See instruction.md §6.
class CurrentLocationMap extends StatefulWidget {
  const CurrentLocationMap({
    super.key,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.onLocated,
    this.zoom = 15.5,
  });

  /// Extra markers to draw on top of the current-location dot.
  final Set<Marker> markers;

  /// Called with the device position once a location fix is obtained
  /// (and again after a retry).
  final void Function(LatLng me)? onLocated;

  /// Optional routes/overlays.
  final Set<Polyline> polylines;

  /// Called once the underlying [GoogleMapController] is ready.
  final void Function(GoogleMapController controller)? onMapCreated;

  /// Initial camera zoom.
  final double zoom;

  @override
  State<CurrentLocationMap> createState() => _CurrentLocationMapState();
}

class _CurrentLocationMapState extends State<CurrentLocationMap> {
  static const _locationService = LocationService();

  // Fallback camera target (central London) shown only until we get a fix.
  static const _fallback = CameraPosition(target: LatLng(51.5074, -0.1278), zoom: 11);

  GoogleMapController? _controller;
  LatLng? _me;
  String? _error;
  bool _errorOpensSettings = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await _locationService.currentPosition();
      if (!mounted) return;
      final me = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _me = me;
        _loading = false;
      });
      widget.onLocated?.call(me);
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: me, zoom: widget.zoom)),
      );
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _errorOpensSettings = e.openAppSettings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't get your location. Please try again.";
        _errorOpensSettings = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition:
                _me == null ? _fallback : CameraPosition(target: _me!, zoom: widget.zoom),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: widget.markers,
            polylines: widget.polylines,
            onMapCreated: (c) {
              _controller = c;
              widget.onMapCreated?.call(c);
              if (_me != null) {
                c.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _me!, zoom: widget.zoom),
                  ),
                );
              }
            },
          ),
        ),
        if (_loading)
          const Positioned.fill(child: ColoredBox(color: Brand.bg, child: _Loading())),
        if (_error != null)
          Positioned.fill(
            child: _LocationError(
              message: _error!,
              opensSettings: _errorOpensSettings,
              onRetry: _resolveLocation,
              onOpenSettings: () => _locationService.openSettings(),
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Brand.blue),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Finding your location…',
            style: TextStyle(color: Brand.sub, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LocationError extends StatelessWidget {
  const _LocationError({
    required this.message,
    required this.opensSettings,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String message;
  final bool opensSettings;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Brand.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 42, color: Brand.faint),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Brand.sub, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: opensSettings ? onOpenSettings : onRetry,
                style: FilledButton.styleFrom(backgroundColor: Brand.blue),
                child: Text(opensSettings ? 'Open settings' : 'Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
