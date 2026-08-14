import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// Turns any thrown object into a sentence a driver can act on.
///
/// Nothing a user sees should ever be a raw exception — `e.toString()` leaks
/// things like `DioException [connection error]: ...` or
/// `PlatformException(sign_in_failed, com.google.android.gms...ApiException: 10,
/// null, null)`, which mean nothing to a driver and look like a broken app.
///
/// [ApiException] already carries a message the API wrote for humans (the
/// problem+json `title`), so that passes through untouched. Anything else is
/// mapped to a plain-English equivalent, with the real error logged in debug
/// builds so it's still diagnosable.
String friendlyError(Object error, [String fallback = 'Something went wrong. Please try again.']) {
  if (kDebugMode) debugPrint('[error] $error');

  return switch (error) {
    final ApiException e => e.message,
    final DioException e => _dioMessage(e),
    SocketException _ => _noConnection,
    TimeoutException _ => 'That took too long. Please check your connection and try again.',
    FormatException _ => 'We got an unexpected response from the server. Please try again.',
    _ => fallback,
  };
}

const _noConnection =
    "Can't reach Mapcars. Please check your internet connection and try again.";

String _dioMessage(DioException e) => switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The connection timed out. Please try again.',
      DioExceptionType.connectionError => _noConnection,
      DioExceptionType.cancel => 'That request was cancelled.',
      // A response came back — reuse the API's own wording.
      _ => ApiException.fromDioError(e).message,
    };
