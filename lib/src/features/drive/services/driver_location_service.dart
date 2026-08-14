import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Reports the driver's live position to the API's Redis GEO hot path.
/// Mirrors `DriverLocationController` — `PUT`/`DELETE /api/v1/drivers/location`.
/// Requires the driver to be signed in (the Dio interceptor attaches the token).
class DriverLocationService {
  DriverLocationService(this._dio);
  final Dio _dio;

  /// Add/move the driver in the live pool. Pass [tripId] while working an
  /// active trip so the API relays position to that trip's SignalR group
  /// (the rider's live tracking). Pass [heading] (degrees, 0 = north,
  /// clockwise) when the device has one, so nearby-car map markers can rotate
  /// to face the direction of travel.
  Future<void> push(double lat, double lng, {String? tripId, double? heading}) =>
      apiCall(() async {
        await _dio.put<void>(
          '/api/v1/drivers/location',
          data: {
            'lat': lat,
            'lng': lng,
            if (tripId != null) 'tripId': tripId,
            if (heading != null) 'heading': heading,
          },
        );
      });

  /// Remove the driver from the live pool (going offline).
  Future<void> goOffline() => apiCall(() async {
        await _dio.delete<void>('/api/v1/drivers/location');
      });
}

final driverLocationServiceProvider = Provider<DriverLocationService>(
  (ref) => DriverLocationService(ref.watch(dioProvider)),
);
