// The kerbside PIN is verified by the API, not only on the phone.
//
// A check that lives only in the app proves nothing — a driver calling the API
// directly skips it. `POST /trips/{id}/start` accepts `{ "pin": "1234" }` and
// refuses a wrong PIN (or too many wrong ones) with a 400 whose `title` is the
// message to show the driver.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/network/api_exception.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';

/// Captures the outgoing request and replies with a canned response.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;
  RequestOptions? seen;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _tripJson = {
  'id': 't1',
  'status': 'InProgress',
  'pickupAddress': 'A',
  'dropoffAddress': 'B',
  'pickupLat': 51.5,
  'pickupLng': -0.1,
  'dropoffLat': 51.6,
  'dropoffLng': -0.2,
  'createdAtUtc': '2026-09-01T12:00:00Z',
};

({TripService service, _CapturingAdapter adapter}) _service(
    int status, Map<String, dynamic> body) {
  final adapter = _CapturingAdapter(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = adapter;
  return (service: TripService(dio), adapter: adapter);
}

void main() {
  test('start() posts the entered PIN to the start endpoint', () async {
    final h = _service(200, _tripJson);

    await h.service.start('t1', pin: '4821');

    expect(h.adapter.seen!.method, 'POST');
    expect(h.adapter.seen!.path, '/api/v1/trips/t1/start');
    expect(h.adapter.seen!.data, {'pin': '4821'});
  });

  test('start() sends no body when the trip has no PIN to enter', () async {
    // A trip booked before PINs existed — the API treats a missing body as
    // "no PIN offered" and lets it through.
    final h = _service(200, _tripJson);

    await h.service.start('t1');

    expect(h.adapter.seen!.data, isNull);
  });

  for (final message in [
    "That PIN doesn't match. Ask the customer to read it out again.",
    'Too many incorrect PIN attempts. Ask the customer to confirm their '
        'booking, or contact support.',
  ]) {
    test('an API rejection surfaces its own message: "$message"', () async {
      final h = _service(400, {'title': message, 'status': 400});

      await expectLater(
        h.service.start('t1', pin: '0000'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', message)
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  }
}
