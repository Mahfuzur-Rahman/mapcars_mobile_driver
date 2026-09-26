import 'dart:io' show HttpDate;

import 'package:flutter/foundation.dart';

/// How far this device's clock sits from the API's.
///
/// Deadlines like a trip's `expiresAtUtc` are written by the server, so a
/// countdown to one has to be measured on the server's clock. Phone clocks are
/// routinely tens of seconds out and occasionally minutes — a customer whose phone
/// runs fast would watch their ride "expire" while it is still perfectly live,
/// and a driver's card would read 0:12 on one handset and 0:31 on the next.
///
/// Every API response carries a `Date` header, so the offset comes free: the
/// client is corrected on every call it already makes. Until the first response
/// lands the offset is zero, which is simply the device clock — the right
/// fallback, since being slightly wrong beats showing nothing.
///
/// This is for *display*. Nothing that matters is decided here: the API refuses
/// a lapsed request on its own clock regardless of what any phone believes.
class ServerClock {
  ServerClock._();

  static Duration _offset = Duration.zero;

  /// Feed the `Date` header of any API response. Ignores anything unparseable.
  static void syncFrom(String? httpDate) {
    if (httpDate == null || httpDate.isEmpty) return;
    try {
      final serverNow = HttpDate.parse(httpDate).toUtc();
      _offset = serverNow.difference(DateTime.now().toUtc());
    } catch (_) {
      // A malformed or missing Date header just leaves the last good offset in
      // place. Never throws into an interceptor.
      if (kDebugMode) debugPrint('[ServerClock] unparseable Date header: $httpDate');
    }
  }

  /// Now, on the server's clock.
  static DateTime get now => DateTime.now().toUtc().add(_offset);

  /// Time left until [deadlineUtc]; [Duration.zero] once it has passed, so
  /// callers can render it without guarding for negatives.
  static Duration remainingUntil(DateTime? deadlineUtc) {
    if (deadlineUtc == null) return Duration.zero;
    final left = deadlineUtc.toUtc().difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @visibleForTesting
  static set offsetForTest(Duration value) => _offset = value;
}
