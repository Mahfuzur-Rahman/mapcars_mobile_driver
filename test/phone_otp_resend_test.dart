// The resend countdown is the server's: resendAfterSeconds on a send, and
// retryAfterSeconds on a 429. Before this the countdown wasn't driven by the
// server at all.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/network/api_exception.dart';
import 'package:mapcars_driver/src/features/auth/models/auth_session.dart';
import 'package:mapcars_driver/src/features/auth/providers/auth_notifier.dart';
import 'package:mapcars_driver/src/features/auth/services/driver_auth_service.dart';
import 'package:mapcars_driver/src/features/auth/services/session_repository.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/widgets/resend_code_button.dart';

class _MemorySessionRepository extends SessionRepository {
  _MemorySessionRepository() : super(const FlutterSecureStorage());
  @override
  Future<void> save(AuthSession session) async {}
  @override
  Future<AuthSession?> load() async => null;
  @override
  Future<void> clear() async {}
}

class _FakeAuthService extends DriverAuthService {
  _FakeAuthService(this.reply) : super(Dio());
  final Future<OtpSentResult> Function() reply;
  @override
  Future<OtpSentResult> sendPhoneOtp(String phone) => reply();
}

DioException _tooMany({Map<String, dynamic>? body, String? retryAfterHeader}) {
  final options = RequestOptions(path: '/api/v1/auth/drivers/send-otp');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: 429,
      data: body,
      headers: Headers.fromMap({
        if (retryAfterHeader != null) 'retry-after': [retryAfterHeader],
      }),
    ),
  );
}

void main() {
  test('ApiException reads retryAfterSeconds from the body, then the header', () {
    expect(
        ApiException.fromDioError(_tooMany(body: {'title': 'Wait', 'retryAfterSeconds': 42}))
            .retryAfterSeconds,
        42);
    expect(ApiException.fromDioError(_tooMany(retryAfterHeader: '17')).retryAfterSeconds, 17);
  });

  ProviderContainer containerWith(Future<OtpSentResult> Function() reply) {
    final c = ProviderContainer(overrides: [
      driverAuthServiceProvider.overrideWithValue(_FakeAuthService(reply)),
      sessionRepositoryProvider.overrideWithValue(_MemorySessionRepository()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('a send starts the countdown from resendAfterSeconds', () async {
    final c = containerWith(
        () async => const OtpSentResult(message: 'sent', resendAfterSeconds: 60));

    final ok = await c.read(authNotifierProvider.notifier).sendPhoneOtp('+447400123456');

    expect(ok, isTrue);
    final wait = c.read(authNotifierProvider).resendAvailableAt!.difference(DateTime.now());
    expect(wait.inSeconds, inInclusiveRange(58, 60));
  });

  test('a 429 restarts the countdown from retryAfterSeconds', () async {
    final c = containerWith(() async => throw ApiException(
        message: 'Please wait 42 seconds before asking for another code.',
        statusCode: 429,
        retryAfterSeconds: 42));

    final ok = await c.read(authNotifierProvider.notifier).sendPhoneOtp('+447400123456');

    expect(ok, isFalse);
    final state = c.read(authNotifierProvider);
    expect(state.error, 'Please wait 42 seconds before asking for another code.');
    expect(state.resendAvailableAt!.difference(DateTime.now()).inSeconds,
        inInclusiveRange(40, 42));
  });

  testWidgets('ResendCodeButton counts down, then offers to resend', (tester) async {
    var resends = 0;
    Widget build(DateTime? at) => MaterialApp(
          home: Scaffold(
            body: ResendCodeButton(availableAt: at, onResend: () => resends++),
          ),
        );

    await tester.pumpWidget(build(DateTime.now().add(const Duration(seconds: 42))));
    expect(find.textContaining('Resend code in 0:4'), findsOneWidget);

    await tester.pumpWidget(build(DateTime.now().subtract(const Duration(seconds: 1))));
    await tester.tap(find.text('Resend code'));
    expect(resends, 1);
  });
}
