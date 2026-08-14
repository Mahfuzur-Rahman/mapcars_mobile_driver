import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// The driver's Stripe Connect payout account status. Mirrors the API's
/// `PayoutAccountResponse` — deliberately minimal (no bank details or next
/// payout date/amount are exposed; Stripe pays out automatically once
/// connected, there's no manual "cash out" action).
class PayoutAccount {
  const PayoutAccount({
    required this.status,
    required this.payoutsEnabled,
    required this.chargesEnabled,
  });

  final String status;
  final bool payoutsEnabled;
  final bool chargesEnabled;

  factory PayoutAccount.fromJson(Map<String, dynamic> j) => PayoutAccount(
        status: j['status'] as String? ?? 'unknown',
        payoutsEnabled: j['payoutsEnabled'] as bool? ?? false,
        chargesEnabled: j['chargesEnabled'] as bool? ?? false,
      );
}

/// A single completed Stripe payout. Mirrors the API's `PayoutResponse`.
class Payout {
  const Payout({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAtUtc,
    this.arrivedAtUtc,
  });

  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAtUtc;
  final DateTime? arrivedAtUtc;

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        id: j['id'].toString(),
        amount: (j['amount'] as num? ?? 0).toDouble(),
        currency: j['currency'] as String? ?? 'gbp',
        status: j['status'] as String? ?? '',
        createdAtUtc: DateTime.parse(j['createdAtUtc'] as String),
        arrivedAtUtc: j['arrivedAtUtc'] == null
            ? null
            : DateTime.parse(j['arrivedAtUtc'] as String),
      );
}

/// Talks to the driver payout endpoints (Stripe Connect). Mirrors
/// `Mapcars.Api/Controllers/DriverPayoutsController.cs` — all under
/// `/api/v1/driver`.
class PayoutService {
  PayoutService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/driver';

  Future<PayoutAccount> getAccountStatus() => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/payout-account');
        return PayoutAccount.fromJson(res.data!);
      });

  /// Starts (or resumes) Stripe Connect onboarding — returns a one-time hosted
  /// onboarding URL to open in the browser. [refreshUrl]/[returnUrl] are where
  /// Stripe sends the browser back to once done; the app has no deep-link
  /// handler for that yet, so the driver switches back to the app manually and
  /// taps refresh.
  Future<String> startOnboarding({
    required String refreshUrl,
    required String returnUrl,
  }) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/payout-account/onboarding-link',
          data: {'refreshUrl': refreshUrl, 'returnUrl': returnUrl},
        );
        return res.data!['url'] as String;
      });

  Future<List<Payout>> listPayouts() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>('$_base/payouts');
        return (res.data ?? [])
            .map((e) => Payout.fromJson(e as Map<String, dynamic>))
            .toList();
      });
}

final payoutServiceProvider = Provider<PayoutService>(
  (ref) => PayoutService(ref.watch(dioProvider)),
);
