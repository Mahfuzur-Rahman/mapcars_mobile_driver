import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_message.dart';

/// Mirrors `Mapcars.Domain.Enums.TripStatus`.
enum TripStatus {
  requested,
  driverAssigned,
  driverArrived,
  inProgress,
  completed,
  cancelledByRider,
  cancelledByDriver,
  unknown;

  static TripStatus fromJson(String? s) => switch (s) {
        'Requested' => TripStatus.requested,
        'DriverAssigned' => TripStatus.driverAssigned,
        'DriverArrived' => TripStatus.driverArrived,
        'InProgress' => TripStatus.inProgress,
        'Completed' => TripStatus.completed,
        'CancelledByRider' => TripStatus.cancelledByRider,
        'CancelledByDriver' => TripStatus.cancelledByDriver,
        _ => TripStatus.unknown,
      };
}

/// The rider's public details — mirrors the API's `TripRiderInfo`. Only sent to
/// this trip's own two parties, so it's null on the open dispatch board.
class TripRider {
  const TripRider({required this.name, this.rating});

  final String name;
  final double? rating;

  factory TripRider.fromJson(Map<String, dynamic> j) => TripRider(
        name: j['name'] as String? ?? 'Your rider',
        rating: (j['rating'] as num?)?.toDouble(),
      );
}

/// A trip as returned by any lifecycle endpoint — mirrors the API's
/// `TripResponse` (`Mapcars.Application/Trips/Dtos/TripResponse.cs`).
class Trip {
  const Trip({
    required this.id,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.status,
    this.fareAmount,
    this.tipAmount = 0,
    this.tier,
    this.distanceMiles,
    this.durationMinutes,
    this.surgeMultiplier,
    this.platformFeeAmount,
    this.driverEarnings,
    this.fareChartVersion,
    required this.createdAtUtc,
    this.completedAtUtc,
    this.cancelledAtUtc,
    this.cancelledReason,
    this.isNoShow = false,
    this.paymentMethod = 'Cash',
    this.paymentStatus = 'Pending',
    this.rider,
    this.pin,
  });

  final String id;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final TripStatus status;
  final double? fareAmount;
  final double tipAmount;
  final String? tier;
  final double? distanceMiles;
  final double? durationMinutes;
  final double? surgeMultiplier;
  final double? platformFeeAmount;
  final double? driverEarnings;
  final int? fareChartVersion;
  final DateTime createdAtUtc;
  final DateTime? completedAtUtc;
  final DateTime? cancelledAtUtc;
  final String? cancelledReason;
  final bool isNoShow;

  /// Payment method ('Cash' | 'Card') and settlement state
  /// ('Pending' | 'Collected' | 'Failed'), from the API's `TripResponse`.
  final String paymentMethod;
  final String paymentStatus;

  /// Who we're collecting. Null on the open board (the API withholds it until
  /// the trip is yours) and on the history list.
  final TripRider? rider;

  /// The rider's 4-digit meet-up code, confirmed at the kerb before starting.
  /// Null for trips booked before PINs existed, and on the open board.
  final String? pin;

  bool get isCash => paymentMethod.toLowerCase() == 'cash';

  /// Pickup / drop-off as map coordinates.
  ({double lat, double lng}) get pickup => (lat: pickupLat, lng: pickupLng);
  ({double lat, double lng}) get dropoff => (lat: dropoffLat, lng: dropoffLng);

  /// Total the rider owes the driver in cash at drop-off (fare + tip).
  double get cashDue => (fareAmount ?? 0) + tipAmount;

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'].toString(),
        pickupAddress: j['pickupAddress'] as String? ?? '',
        pickupLat: (j['pickupLat'] as num? ?? 0).toDouble(),
        pickupLng: (j['pickupLng'] as num? ?? 0).toDouble(),
        dropoffAddress: j['dropoffAddress'] as String? ?? '',
        dropoffLat: (j['dropoffLat'] as num? ?? 0).toDouble(),
        dropoffLng: (j['dropoffLng'] as num? ?? 0).toDouble(),
        status: TripStatus.fromJson(j['status'] as String?),
        fareAmount: (j['fareAmount'] as num?)?.toDouble(),
        tipAmount: (j['tipAmount'] as num?)?.toDouble() ?? 0,
        tier: j['tier'] as String?,
        distanceMiles: (j['distanceMiles'] as num?)?.toDouble(),
        durationMinutes: (j['durationMinutes'] as num?)?.toDouble(),
        surgeMultiplier: (j['surgeMultiplier'] as num?)?.toDouble(),
        platformFeeAmount: (j['platformFeeAmount'] as num?)?.toDouble(),
        driverEarnings: (j['driverEarnings'] as num?)?.toDouble(),
        fareChartVersion: j['fareChartVersion'] as int?,
        createdAtUtc: DateTime.parse(j['createdAtUtc'] as String),
        completedAtUtc: j['completedAtUtc'] == null
            ? null
            : DateTime.parse(j['completedAtUtc'] as String),
        cancelledAtUtc: j['cancelledAtUtc'] == null
            ? null
            : DateTime.parse(j['cancelledAtUtc'] as String),
        cancelledReason: j['cancelledReason'] as String?,
        isNoShow: j['isNoShow'] as bool? ?? false,
        paymentMethod: j['paymentMethod'] as String? ?? 'Cash',
        paymentStatus: j['paymentStatus'] as String? ?? 'Pending',
        rider: j['rider'] is Map<String, dynamic>
            ? TripRider.fromJson(j['rider'] as Map<String, dynamic>)
            : null,
        pin: j['pin'] as String?,
      );
}

/// Talks to the driver-facing trip lifecycle endpoints. Mirrors
/// `Mapcars.Api/Controllers/DriverTripsController.cs` (available/available-nearby/
/// mine/accept/arrive/start/complete) and `TripActionsController.cs` (cancel) —
/// all under `/api/v1/trips`.
class TripService {
  TripService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/trips';

  /// `GET /trips/available` — every unassigned open trip request, unfiltered
  /// by distance (the full broadcast board).
  Future<List<Trip>> available() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>('$_base/available');
        return (res.data ?? [])
            .map((e) => Trip.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// `GET /trips/available/nearby` — open requests near the driver (their
  /// board), nearest first. This is the live dispatch board: it's seeded from
  /// this call, then kept current by the `tripAvailable`/`tripUpdated`
  /// SignalR pushes (see `DispatchBoardController`).
  Future<List<Trip>> availableNearby({
    required double lat,
    required double lng,
    double? radiusMeters,
  }) =>
      apiCall(() async {
        final res = await _dio.get<List<dynamic>>(
          '$_base/available/nearby',
          queryParameters: {
            'lat': lat,
            'lng': lng,
            if (radiusMeters != null) 'radiusMeters': radiusMeters,
          },
        );
        return (res.data ?? [])
            .map((e) => Trip.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// `GET /trips/{id}` — one trip in full. Unlike the list endpoints, this one
  /// carries the party-only fields (rider details and the meet-up PIN), so a
  /// trip picked out of [mine] must be re-fetched through here before the
  /// arrived screen can ask for a PIN it would otherwise not have.
  Future<Trip> get(String tripId) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/$tripId');
        return Trip.fromJson(res.data!);
      });

  /// `GET /trips/mine` — the signed-in driver's own trips.
  Future<List<Trip>> mine() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>('$_base/mine');
        return (res.data ?? [])
            .map((e) => Trip.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// `POST /trips/{id}/accept` — first-come wins; throws (via [ApiException])
  /// if another driver already took it.
  Future<Trip> accept(String tripId) => apiCall(() async {
        final res =
            await _dio.post<Map<String, dynamic>>('$_base/$tripId/accept');
        return Trip.fromJson(res.data!);
      });

  Future<Trip> arrive(String tripId) => apiCall(() async {
        final res =
            await _dio.post<Map<String, dynamic>>('$_base/$tripId/arrive');
        return Trip.fromJson(res.data!);
      });

  Future<Trip> start(String tripId) => apiCall(() async {
        final res =
            await _dio.post<Map<String, dynamic>>('$_base/$tripId/start');
        return Trip.fromJson(res.data!);
      });

  Future<Trip> complete(String tripId) => apiCall(() async {
        final res =
            await _dio.post<Map<String, dynamic>>('$_base/$tripId/complete');
        return Trip.fromJson(res.data!);
      });

  /// `isNoShow` only takes effect server-side once the driver has already
  /// called [arrive] on this trip — the API ignores the flag otherwise.
  Future<Trip> cancel(String tripId, {String? reason, bool isNoShow = false}) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/$tripId/cancel',
          data: {
            if (reason != null && reason.isNotEmpty) 'reason': reason,
            'isNoShow': isNoShow,
          },
        );
        return Trip.fromJson(res.data!);
      });

  /// `GET /trips/{id}/messages` — full chat history for this trip.
  Future<List<ChatMessage>> getMessages(String tripId) =>
      apiCall(() async {
        final res = await _dio.get<List<dynamic>>('$_base/$tripId/messages');
        return (res.data ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// `POST /trips/{id}/messages` — send a chat message.
  Future<ChatMessage> sendMessage(String tripId, {required String content}) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/$tripId/messages',
          data: {'content': content},
        );
        return ChatMessage.fromJson(res.data!);
      });
}

final tripServiceProvider = Provider<TripService>(
  (ref) => TripService(ref.watch(dioProvider)),
);
