import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// The driver's registered vehicle. Mirrors the API's `VehicleResponse`
/// (`Mapcars.Application/Vehicles/Dtos/VehicleDtos.cs`).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.colour,
    required this.registrationNumber,
    this.phvLicencePlateNumber,
    this.phvLicensingAuthority,
    this.tier = 'economy',
  });

  final String id;
  final String make;
  final String model;
  final int year;
  final String colour;
  final String registrationNumber;
  final String? phvLicencePlateNumber;
  final String? phvLicensingAuthority;
  final String tier;

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'].toString(),
        make: j['make'] as String? ?? '',
        model: j['model'] as String? ?? '',
        year: j['year'] as int? ?? 0,
        colour: j['colour'] as String? ?? '',
        registrationNumber: j['registrationNumber'] as String? ?? '',
        phvLicencePlateNumber: j['phvLicencePlateNumber'] as String?,
        phvLicensingAuthority: j['phvLicensingAuthority'] as String?,
        tier: (j['tier'] as String? ?? 'economy').toLowerCase(),
      );
}

/// A driver's request to upgrade vehicle tier. Mirrors `VehicleTierAppealResponse`.
class TierAppeal {
  const TierAppeal({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.currentTier,
    required this.requestedTier,
    required this.reason,
    required this.photoUrls,
    required this.status,
    this.adminNotes,
    this.reviewedAtUtc,
    required this.createdAtUtc,
  });

  final String id;
  final String driverId;
  final String vehicleId;
  final String currentTier;
  final String requestedTier;
  final String reason;
  final List<String> photoUrls;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final String? adminNotes;
  final DateTime? reviewedAtUtc;
  final DateTime createdAtUtc;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';

  factory TierAppeal.fromJson(Map<String, dynamic> j) => TierAppeal(
        id: j['id'].toString(),
        driverId: j['driverId'].toString(),
        vehicleId: j['vehicleId'].toString(),
        currentTier: j['currentTier'] as String? ?? 'economy',
        requestedTier: j['requestedTier'] as String? ?? 'comfort',
        reason: j['reason'] as String? ?? '',
        photoUrls: (j['photoUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: j['status'] as String? ?? 'Pending',
        adminNotes: j['adminNotes'] as String?,
        reviewedAtUtc: j['reviewedAtUtc'] != null
            ? DateTime.tryParse(j['reviewedAtUtc'] as String)
            : null,
        createdAtUtc: DateTime.tryParse(j['createdAtUtc'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Talks to `/api/v1/vehicles` — the authenticated driver's vehicle and tier appeals.
class VehicleService {
  VehicleService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/vehicles';

  /// `GET /vehicles/me` — null (API returns 204) if the driver hasn't
  /// registered a vehicle yet.
  Future<Vehicle?> getMine() => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/me');
        final data = res.data;
        if (res.statusCode == 204 || data == null) return null;
        return Vehicle.fromJson(data);
      });

  /// `PUT /vehicles/me` — create or replace the driver's vehicle.
  Future<Vehicle> upsert({
    required String make,
    required String model,
    required int year,
    required String colour,
    required String registrationNumber,
    String? phvLicencePlateNumber,
    String? phvLicensingAuthority,
  }) =>
      apiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '$_base/me',
          data: {
            'make': make,
            'model': model,
            'year': year,
            'colour': colour,
            'registrationNumber': registrationNumber,
            if (phvLicencePlateNumber != null && phvLicencePlateNumber.isNotEmpty)
              'phvLicencePlateNumber': phvLicencePlateNumber,
            if (phvLicensingAuthority != null && phvLicensingAuthority.isNotEmpty)
              'phvLicensingAuthority': phvLicensingAuthority,
          },
        );
        return Vehicle.fromJson(res.data!);
      });

  /// `POST /vehicles/me/appeals` — submit a tier change appeal with optional photos.
  Future<TierAppeal> submitAppeal({
    required String requestedTier,
    required String reason,
    List<String>? photoPaths,
  }) =>
      apiCall(() async {
        if (photoPaths != null && photoPaths.isNotEmpty) {
          final formData = FormData.fromMap({
            'requestedTier': requestedTier,
            'reason': reason,
          });

          for (final path in photoPaths) {
            formData.files.add(
              MapEntry(
                'photos',
                await MultipartFile.fromFile(
                  path,
                  filename: path.split(RegExp(r'[/\\]')).last,
                ),
              ),
            );
          }

          final res = await _dio.post<Map<String, dynamic>>(
            '$_base/me/appeals',
            data: formData,
          );
          return TierAppeal.fromJson(res.data!);
        } else {
          final res = await _dio.post<Map<String, dynamic>>(
            '$_base/me/appeals/json',
            data: {
              'requestedTier': requestedTier,
              'reason': reason,
            },
          );
          return TierAppeal.fromJson(res.data!);
        }
      });

  /// `GET /vehicles/me/appeals` — list all tier appeals for this vehicle.
  Future<List<TierAppeal>> getAppeals() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>('$_base/me/appeals');
        final data = res.data;
        if (data == null) return [];
        return data
            .map((e) => TierAppeal.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// `GET /vehicles/me/appeals/active` — returns current active pending appeal (or null).
  Future<TierAppeal?> getActiveAppeal() => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/me/appeals/active');
        final data = res.data;
        if (res.statusCode == 204 || data == null) return null;
        return TierAppeal.fromJson(data);
      });
}

final vehicleServiceProvider = Provider<VehicleService>(
  (ref) => VehicleService(ref.watch(dioProvider)),
);
