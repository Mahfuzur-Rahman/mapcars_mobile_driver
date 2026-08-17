import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// One uploaded document — mirrors the API's `DocumentResponse`
/// (Mapcars.Application.Documents.Dtos.DocumentResponse).
class DriverDocument {
  const DriverDocument({
    required this.id,
    required this.type,
    required this.originalFileName,
    required this.reviewStatus,
    required this.createdAtUtc,
    this.reviewedAtUtc,
    this.expiresOn,
    this.isDeletionRequested = false,
    this.deletionReason,
    this.deletionRequestedAtUtc,
  });

  final String id;

  /// DocumentType enum name, e.g. "PhvLicence", "VehicleInsurance".
  final String type;
  final String originalFileName;

  /// "Pending" | "Approved" | "Rejected".
  final String reviewStatus;
  final DateTime createdAtUtc;
  final DateTime? reviewedAtUtc;

  /// Expiry date, required by the API for PhvLicence/VehicleInsurance/
  /// VehicleRegistration/DbsCheck — null for the vehicle-photo types.
  final DateTime? expiresOn;

  final bool isDeletionRequested;
  final String? deletionReason;
  final DateTime? deletionRequestedAtUtc;

  factory DriverDocument.fromJson(Map<String, dynamic> j) => DriverDocument(
        id: j['id'].toString(),
        type: j['type'] as String,
        originalFileName: j['originalFileName'] as String? ?? '',
        reviewStatus: j['reviewStatus'] as String? ?? 'Pending',
        createdAtUtc: DateTime.parse(j['createdAtUtc'] as String),
        reviewedAtUtc: j['reviewedAtUtc'] == null
            ? null
            : DateTime.parse(j['reviewedAtUtc'] as String),
        expiresOn: j['expiresOn'] == null
            ? null
            : DateTime.parse(j['expiresOn'] as String),
        isDeletionRequested: j['isDeletionRequested'] as bool? ?? false,
        deletionReason: j['deletionReason'] as String?,
        deletionRequestedAtUtc: j['deletionRequestedAtUtc'] == null
            ? null
            : DateTime.parse(j['deletionRequestedAtUtc'] as String),
      );
}

/// Talks to the shared documents endpoint. Mirrors
/// `Mapcars.Api/Controllers/DocumentsController.cs` (`/api/v1/documents`).
/// The API decides which DocumentType values are valid for a driver.
class DriverDocumentsService {
  DriverDocumentsService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/documents';

  Future<List<DriverDocument>> list() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>(_base);
        return (res.data ?? [])
            .map((e) => DriverDocument.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Uploads [file] as [type] (a DocumentType enum name). Sends multipart —
  /// the API validates size/content-type and streams it to private R2 storage.
  /// [expiresOn] is required by the API for the expiring document types
  /// (PhvLicence/VehicleInsurance/VehicleRegistration/DbsCheck).
  Future<DriverDocument> upload(String type, File file, {DateTime? expiresOn}) =>
      apiCall(() async {
        final formData = FormData.fromMap({
          'type': type,
          'file': await MultipartFile.fromFile(file.path),
          if (expiresOn != null)
            'expiresOn':
                '${expiresOn.year.toString().padLeft(4, '0')}-${expiresOn.month.toString().padLeft(2, '0')}-${expiresOn.day.toString().padLeft(2, '0')}',
        });
        final res = await _dio.post<Map<String, dynamic>>(_base, data: formData);
        return DriverDocument.fromJson(res.data!);
      });

  /// Requests the document to be deleted by admin.
  Future<DriverDocument> requestDeletion(String documentId, {String? reason}) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/$documentId/request-deletion',
          data: {
            if (reason != null && reason.trim().isNotEmpty)
              'reason': reason.trim(),
          },
        );
        return DriverDocument.fromJson(res.data!);
      });

  /// Returns full URL to stream document bytes.
  String getDocumentContentUrl(String documentId) {
    final baseUrl = _dio.options.baseUrl;
    return '$baseUrl$_base/$documentId/content';
  }
}

final driverDocumentsServiceProvider = Provider<DriverDocumentsService>(
  (ref) => DriverDocumentsService(ref.watch(dioProvider)),
);
