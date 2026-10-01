// A TestFlight tester's customer-app sign-up died with Dio's raw "The request connection
// took longer than 0:00:15.000000 … RequestOptions.connectTimeout" text, and
// the request never reached the API — so nothing on our side could say why.
// When the API can't be reached the app now diagnoses it from the phone and
// shows the result in a sentence a person can screenshot.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/network/api_client.dart';
import 'package:mapcars_driver/src/core/network/friendly_error.dart';
import 'package:mapcars_driver/src/core/network/network_diagnosis.dart';

final _serverIp = InternetAddress('34.13.55.100');

NetworkDiagnoser _diagnoser({
  Future<List<InternetAddress>> Function(String)? lookup,
  Future<void> Function(InternetAddress, int, Duration)? connect,
  bool internet = true,
  void Function(NetworkDiagnosis)? onDiagnosed,
}) =>
    NetworkDiagnoser(
      apiBaseUrl: 'https://gce-test.mapcars.uk',
      lookup: lookup ?? (_) async => [_serverIp],
      connect: connect ?? (_, __, ___) async {},
      internetCheck: (_) async => internet,
      networkType: () async => 'wifi',
      probeTimeout: const Duration(milliseconds: 50),
      onDiagnosed: onDiagnosed,
    );

DioException _timedOut([NetworkDiagnosis? diagnosis]) {
  final options = RequestOptions(path: '/api/v1/auth/drivers/signup');
  if (diagnosis != null) options.extra[networkDiagnosisKey] = diagnosis;
  return DioException.connectionTimeout(
    timeout: const Duration(seconds: 15),
    requestOptions: options,
  );
}

void main() {
  test('server unreachable while the internet works', () async {
    final d = await _diagnoser(
      connect: (_, __, ___) => Completer<void>().future, // never connects
    ).diagnose();

    expect(d.summary,
        'gce-test.mapcars.uk · dns 34.13.55.100 · tcp timeout · internet ok · net wifi');
  });

  test('a DNS failure skips the connect and says so', () async {
    var connected = false;
    final d = await _diagnoser(
      lookup: (_) async => throw const SocketException('Failed host lookup'),
      connect: (_, __, ___) async => connected = true,
    ).diagnose();

    expect(d.dns, 'fail');
    expect(d.tcp, 'skipped');
    expect(connected, isFalse);
  });

  test('a refused connection is told apart from a timeout', () async {
    final d = await _diagnoser(
      connect: (_, __, ___) async => throw const SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 61)),
    ).diagnose();

    expect(d.tcp, 'refused');
  });

  test('repeated failures reuse one diagnosis and report it once', () async {
    var reports = 0;
    final diagnoser = _diagnoser(onDiagnosed: (_) => reports++);

    final first = diagnoser.diagnose();
    final concurrent = diagnoser.diagnose();
    expect(identical(await first, await concurrent), isTrue);
    await diagnoser.diagnose();

    expect(reports, 1);
  });

  test('the screen never shows Dio\'s raw timeout text', () async {
    const diagnosis = NetworkDiagnosis(
      host: 'gce-test.mapcars.uk',
      dns: '34.13.55.100',
      tcp: 'timeout',
      internet: 'ok',
      network: 'wifi',
    );

    // The path every auth service takes: apiCall → ApiException.
    Object? thrown;
    try {
      await apiCall<void>(() => throw _timedOut(diagnosis));
    } catch (e) {
      thrown = e;
    }

    for (final message in [thrown.toString(), friendlyError(_timedOut(diagnosis))]) {
      expect(message, isNot(contains('RequestOptions')));
      expect(message, startsWith("Can't reach Mapcars."));
      expect(message, endsWith('Ref: ${diagnosis.summary}'));
    }
  });

  test('without a diagnosis the plain sentence still replaces Dio\'s', () {
    expect(friendlyError(_timedOut()),
        "Can't reach Mapcars. Please check your internet connection and try again.");
  });
}
