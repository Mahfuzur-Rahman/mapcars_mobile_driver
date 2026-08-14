import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A driving route from the Google Directions API — the decoded polyline plus
/// human-readable distance / duration for the trip summary.
class DirectionsResult {
  const DirectionsResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.bounds,
  });

  final List<LatLng> points;
  final String distanceText; // "4.3 mi"
  final String durationText; // "12 mins"
  final int distanceMeters;
  final int durationSeconds;
  final LatLngBounds bounds;
}
