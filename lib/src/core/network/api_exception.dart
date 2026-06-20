import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({required this.message, this.statusCode, this.errors});

  final int? statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  factory ApiException.fromDioError(DioException e) {
    final data = e.response?.data;
    String msg = _httpMessage(e);

    if (data is Map<String, dynamic>) {
      msg = (data['title'] as String?) ?? msg;
    }

    return ApiException(
      message: msg,
      statusCode: e.response?.statusCode,
      errors: data is Map<String, dynamic>
          ? data['errors'] as Map<String, dynamic>?
          : null,
    );
  }

  static String _httpMessage(DioException e) => switch (e.response?.statusCode) {
        400 => 'Invalid request.',
        401 => 'Incorrect code or credentials.',
        403 => 'You do not have permission.',
        404 => 'Not found.',
        429 => 'Too many attempts. Please wait.',
        500 => 'Server error. Please try again later.',
        _ => e.message ?? 'An unexpected error occurred.',
      };

  @override
  String toString() => message;
}
