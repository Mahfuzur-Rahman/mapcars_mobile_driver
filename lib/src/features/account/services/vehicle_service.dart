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
  });

  final String id;
  final String make;
  final String model;
  final int year;
  final String colour;
  final String registrationNumber;
  final String? phvLicencePlateNumber;
  final String? phvLicensingAuthority;

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'].toString(),
        make: j['make'] as String? ?? '',
        model: j['model'] as String? ?? '',
        year: j['year'] as int? ?? 0,
        colour: j['colour'] as String? ?? '',
        registrationNumber: j['registrationNumber'] as String? ?? '',
        phvLicencePlateNumber: j['phvLicencePlateNumber'] as String?,
        phvLicensingAuthority: j['phvLicensingAuthority'] as String?,
      );
}

/// Talks to `/api/v1/vehicles/me` — the authenticated driver's own vehicle.
/// Mirrors `Mapcars.Api/Controllers/VehiclesController.cs`.
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
}

final vehicleServiceProvider = Provider<VehicleService>(
  (ref) => VehicleService(ref.watch(dioProvider)),
);
