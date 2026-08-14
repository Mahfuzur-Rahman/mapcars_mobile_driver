import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/utils/polyline_codec.dart';
import '../models/directions_result.dart';
import '../models/place.dart';
import '../models/place_prediction.dart';

/// Raised when a Google Maps web-service call can't be completed — carries a
/// user-facing [message] the search UI can show directly.
class MapsServiceException implements Exception {
  const MapsServiceException(this.message);
  final String message;
  @override
  String toString() => 'MapsServiceException: $message';
}

/// Client for Google's Places + Directions web services. This talks to Google
/// directly for now; when the backend `/api/v1/places` and `/api/v1/directions`
/// endpoints land, swap the base URL to the Mapcars API and drop the key.
class GoogleMapsService {
  GoogleMapsService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://maps.googleapis.com/maps/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  String get _key => Env.googleMapsKey;

  void _ensureKey() {
    if (_key.isEmpty || _key == 'pk.replace_me') {
      throw const MapsServiceException(
        'Maps key not configured. Set GOOGLE_MAPS_KEY in .env (Places + '
        'Directions APIs enabled).',
      );
    }
  }

  /// Address suggestions for [query]. [origin], when given, biases results
  /// toward the user's location. Returns an empty list for blank queries.
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    LatLng? origin,
  }) async {
    if (query.trim().isEmpty) return const [];
    _ensureKey();
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': _key,
          if (Env.placesCountries.isNotEmpty)
            'components':
                Env.placesCountries.map((c) => 'country:$c').join('|'),
          if (origin != null) 'location': '${origin.latitude},${origin.longitude}',
          if (origin != null) 'radius': 30000,
        },
      );
      final data = res.data ?? const {};
      final status = data['status'] as String? ?? 'UNKNOWN';
      if (status == 'ZERO_RESULTS') return const [];
      if (status != 'OK') throw MapsServiceException(_statusMessage(status, data));
      return ((data['predictions'] as List<dynamic>?) ?? const [])
          .map((e) => PlacePrediction.fromJson(e as Map<String, dynamic>))
          .where((p) => p.placeId.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (e) {
      throw MapsServiceException(_networkMessage(e));
    }
  }

  /// Resolves a [PlacePrediction.placeId] to a concrete [Place] with coordinates.
  Future<Place> placeDetails(String placeId) async {
    _ensureKey();
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'key': _key,
          'fields': 'name,formatted_address,geometry',
        },
      );
      final data = res.data ?? const {};
      final status = data['status'] as String? ?? 'UNKNOWN';
      if (status != 'OK') throw MapsServiceException(_statusMessage(status, data));
      final result = data['result'] as Map<String, dynamic>;
      final loc = (result['geometry']
          as Map<String, dynamic>)['location'] as Map<String, dynamic>;
      return Place(
        label: result['name'] as String? ?? 'Selected place',
        address: result['formatted_address'] as String? ?? '',
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
      );
    } on DioException catch (e) {
      throw MapsServiceException(_networkMessage(e));
    }
  }

  /// Driving directions between two points.
  Future<DirectionsResult> directions({
    required LatLng origin,
    required LatLng destination,
  }) async {
    _ensureKey();
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/directions/json',
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'units': 'imperial',
          'key': _key,
        },
      );
      final data = res.data ?? const {};
      final status = data['status'] as String? ?? 'UNKNOWN';
      if (status != 'OK') throw MapsServiceException(_statusMessage(status, data));

      final route = (data['routes'] as List<dynamic>).first as Map<String, dynamic>;
      final leg = ((route['legs'] as List<dynamic>).first) as Map<String, dynamic>;
      final overview = route['overview_polyline'] as Map<String, dynamic>;
      final b = route['bounds'] as Map<String, dynamic>;
      final ne = b['northeast'] as Map<String, dynamic>;
      final sw = b['southwest'] as Map<String, dynamic>;

      return DirectionsResult(
        points: decodePolyline(overview['points'] as String),
        distanceText: (leg['distance'] as Map<String, dynamic>)['text'] as String,
        durationText: (leg['duration'] as Map<String, dynamic>)['text'] as String,
        distanceMeters:
            (leg['distance'] as Map<String, dynamic>)['value'] as int,
        durationSeconds:
            (leg['duration'] as Map<String, dynamic>)['value'] as int,
        bounds: LatLngBounds(
          southwest: LatLng((sw['lat'] as num).toDouble(), (sw['lng'] as num).toDouble()),
          northeast: LatLng((ne['lat'] as num).toDouble(), (ne['lng'] as num).toDouble()),
        ),
      );
    } on DioException catch (e) {
      throw MapsServiceException(_networkMessage(e));
    }
  }

  String _statusMessage(String status, Map<String, dynamic> data) {
    final detail = data['error_message'] as String?;
    return switch (status) {
      'REQUEST_DENIED' => detail ??
          'Maps request denied — check the API key and that Places/Directions '
              'are enabled.',
      'OVER_QUERY_LIMIT' => 'Maps quota exceeded. Try again shortly.',
      'NOT_FOUND' || 'ZERO_RESULTS' => 'No route found for that address.',
      _ => detail ?? "Couldn't reach maps service ($status).",
    };
  }

  String _networkMessage(DioException e) =>
      "Couldn't reach the maps service. Check your connection.";
}

final googleMapsServiceProvider =
    Provider<GoogleMapsService>((ref) => GoogleMapsService());
