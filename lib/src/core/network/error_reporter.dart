import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/env.dart';
import 'api_exception.dart';

/// Ships crashes from this app to the central error log
/// (`POST /api/v1/error-logs` → admin portal → Error Logger).
///
/// Three rules, all of them about not making a bad moment worse:
///
/// * **It never throws.** Every path swallows its own failure. Something has
///   already gone wrong by the time we get here.
/// * **It never blocks the UI.** Reports are fire-and-forget.
/// * **It doesn't echo the server.** An [ApiException] means the API already
///   failed *and logged it itself* — reporting that back would write every
///   server error twice.
///
/// Wired up in `main()` via [ErrorReporter.install], which catches everything
/// Flutter surfaces: framework build/layout errors and uncaught async errors.
class ErrorReporter {
  ErrorReporter._();

  /// Which app this is, as the API's ErrorSource enum spells it.
  static const _source = 'DriverApp';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// The screen the driver was on, kept current by the router so a report says
  /// where it happened, not just what happened.
  static String? currentRoute;

  /// Hooks Flutter's two global error channels. Call once from `main()`.
  static void install() {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details); // keep the red screen / console output
      report(details.exception, details.stack, context: details.library);
    };

    // Uncaught errors from the engine/async gaps that never reach FlutterError.
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, level: 'Fatal');
      return true; // handled — don't take the isolate down
    };
  }

  /// Reports one error. Safe to call from anywhere, including a catch block.
  static void report(
    Object error,
    StackTrace? stack, {
    String? context,
    String level = 'Error',
  }) {
    // The API logs its own failures; see the class doc.
    if (error is ApiException) return;

    if (kDebugMode) debugPrint('[error-report] $error');

    unawaited(_send(error, stack, context, level));
  }

  static Future<void> _send(
    Object error,
    StackTrace? stack,
    String? context,
    String level,
  ) async {
    try {
      await _dio.post<void>('/api/v1/error-logs', data: {
        'source': _source,
        'level': level,
        'message': context == null ? error.toString() : '$context: $error',
        'exceptionType': error.runtimeType.toString(),
        'stackTrace': stack?.toString(),
        'path': currentRoute,
        'appVersion': AppConfig.appVersion.isEmpty ? null : AppConfig.appVersion,
        'platform': _platform(),
      });
    } catch (e) {
      // The reporter itself failing is not worth another report — and must
      // never propagate out of an error handler.
      if (kDebugMode) debugPrint('[error-report] failed to send: $e');
    }
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }
}
