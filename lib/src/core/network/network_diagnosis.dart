import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../config/env.dart';
import 'error_reporter.dart';

/// What the phone could and couldn't reach when a request to the API never
/// connected.
///
/// A bare "connection timed out" can't say whose fault it is — a wrong API
/// address baked into the build, a DNS filter blocking our domain, a network
/// that can't route to the server, or no internet at all. And none of those
/// can be investigated from our side: a request that never connected leaves no
/// trace in the API's logs, and we can't ask every tester or customer to run
/// checks. So the app runs them itself, the moment it happens, and the
/// one-line [summary] goes two places:
///
/// * into the error message on screen — a screenshot carries the diagnosis;
/// * through [ErrorReporter], whose Crashlytics sink reports to Google, not to
///   the server we just failed to reach.
class NetworkDiagnosis {
  const NetworkDiagnosis({
    required this.host,
    required this.dns,
    required this.tcp,
    required this.internet,
    required this.network,
  });

  /// The API host this build actually points at (from the bundled `.env`).
  final String host;

  /// The addresses [host] resolved to, or why the lookup failed.
  final String dns;

  /// A raw TCP connect to the API: `ok`, `timeout`, `refused`, `fail` or
  /// `skipped` (nothing to connect to because DNS failed).
  final String tcp;

  /// Whether a well-known site answers over HTTPS: `ok` or `fail`.
  final String internet;

  /// The interfaces the OS reports, e.g. `wifi`, `mobile`, `vpn`.
  final String network;

  String get summary =>
      '$host · dns $dns · tcp $tcp · internet $internet · net $network';

  @override
  String toString() => 'API unreachable: $summary';
}

/// Runs the checks behind [NetworkDiagnosis]. Every probe is injectable so the
/// logic is testable without a network.
class NetworkDiagnoser {
  NetworkDiagnoser({
    required this.apiBaseUrl,
    Future<List<InternetAddress>> Function(String host)? lookup,
    Future<void> Function(InternetAddress address, int port, Duration timeout)?
        connect,
    Future<bool> Function(Duration timeout)? internetCheck,
    Future<String> Function()? networkType,
    this.probeTimeout = const Duration(seconds: 3),
    this.cacheFor = const Duration(minutes: 1),
    this.onDiagnosed,
  })  : _lookup = lookup ?? InternetAddress.lookup,
        _connect = connect ?? _tcpConnect,
        _internetCheck = internetCheck ?? _httpsCheck,
        _networkType = networkType ?? _connectivity;

  final String apiBaseUrl;
  final Future<List<InternetAddress>> Function(String) _lookup;
  final Future<void> Function(InternetAddress, int, Duration) _connect;
  final Future<bool> Function(Duration) _internetCheck;
  final Future<String> Function() _networkType;

  /// Per probe. Probes run in parallel where they can, so a failure waits at
  /// most two of these (DNS, then TCP) on top of the original timeout. Our API
  /// connects in ~0.3s, so 3s is already "broken".
  final Duration probeTimeout;

  /// A screen that retries, or several requests failing together, reuse one
  /// result instead of re-probing and re-reporting each time.
  final Duration cacheFor;

  /// Called once per fresh diagnosis (not for cached ones).
  final void Function(NetworkDiagnosis)? onDiagnosed;

  /// The app-wide instance, reporting through [ErrorReporter].
  static final NetworkDiagnoser shared = NetworkDiagnoser(
    apiBaseUrl: Env.apiBaseUrl,
    onDiagnosed: (d) => ErrorReporter.report(d, StackTrace.current,
        context: 'api-unreachable'),
  );

  NetworkDiagnosis? _last;
  DateTime? _lastAt;
  Future<NetworkDiagnosis>? _inFlight;

  /// Diagnoses now, or returns the recent result. Never throws.
  Future<NetworkDiagnosis> diagnose() {
    final last = _last;
    if (last != null &&
        _lastAt != null &&
        DateTime.now().difference(_lastAt!) < cacheFor) {
      return Future.value(last);
    }
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<NetworkDiagnosis> _run() async {
    final uri = Uri.tryParse(apiBaseUrl);
    final host = (uri == null || uri.host.isEmpty) ? '"$apiBaseUrl"' : uri.host;

    final results = await Future.wait([
      uri == null || uri.host.isEmpty
          ? Future.value(('invalid', 'skipped'))
          : _dnsThenTcp(uri.host, uri.port),
      _guard(() async =>
          await _internetCheck(probeTimeout) ? 'ok' : 'fail'),
      _guard(_networkType),
    ]);

    final (dns, tcp) = results[0] as (String, String);
    final diagnosis = NetworkDiagnosis(
      host: host,
      dns: dns,
      tcp: tcp,
      internet: results[1] as String,
      network: results[2] as String,
    );

    _last = diagnosis;
    _lastAt = DateTime.now();
    try {
      onDiagnosed?.call(diagnosis);
    } catch (_) {
      // Reporting is best-effort; the diagnosis still reaches the screen.
    }
    return diagnosis;
  }

  Future<(String, String)> _dnsThenTcp(String host, int port) async {
    final List<InternetAddress> addresses;
    try {
      addresses = await _lookup(host).timeout(probeTimeout);
    } on TimeoutException {
      return ('timeout', 'skipped');
    } catch (_) {
      return ('fail', 'skipped');
    }
    if (addresses.isEmpty) return ('none', 'skipped');

    // Two is enough to spot a wrong or sinkholed address (0.0.0.0, a filter's
    // block page) without the line running off the screen.
    final dns = addresses.take(2).map((a) => a.address).join(',');
    try {
      await _connect(addresses.first, port, probeTimeout)
          .timeout(probeTimeout + const Duration(milliseconds: 500));
      return (dns, 'ok');
    } on TimeoutException {
      return (dns, 'timeout');
    } on SocketException catch (e) {
      final message = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
      if (message.contains('timed out')) return (dns, 'timeout');
      if (message.contains('refused')) return (dns, 'refused');
      return (dns, 'fail');
    } catch (_) {
      return (dns, 'fail');
    }
  }

  static Future<String> _guard(Future<String> Function() probe) async {
    try {
      return await probe();
    } catch (_) {
      return 'fail';
    }
  }

  static Future<void> _tcpConnect(
      InternetAddress address, int port, Duration timeout) async {
    final socket = await Socket.connect(address, port, timeout: timeout);
    socket.destroy();
  }

  /// Google's connectivity check, then Apple's captive-portal page — two
  /// unrelated hosts, so one being blocked doesn't read as "no internet".
  static Future<bool> _httpsCheck(Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      for (final url in const [
        'https://clients3.google.com/generate_204',
        'https://captive.apple.com/hotspot-detect.html',
      ]) {
        try {
          final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
          final response = await request.close().timeout(timeout);
          await response.drain<void>();
          if (response.statusCode < 400) return true;
        } catch (_) {
          // Try the next one.
        }
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _connectivity() async {
    final results = await Connectivity()
        .checkConnectivity()
        .timeout(const Duration(seconds: 2));
    return results.map((r) => r.name).join('+');
  }
}

/// Whether [e] means the API was never reached at all — as opposed to a slow
/// or refused request, which the API would have seen (and logged) itself.
bool isUnreachable(DioException e) =>
    e.response == null &&
    (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError);

/// Where the API client's interceptor leaves the diagnosis on a failed request.
const networkDiagnosisKey = 'mapcars.networkDiagnosis';

const _unreachable =
    "Can't reach Mapcars. Please check your internet connection and try again.";

/// The sentence to show for an unreachable API, with the diagnosis attached
/// when one was taken. Null if [e] isn't an unreachable-API failure.
String? unreachableMessage(DioException e) {
  if (!isUnreachable(e)) return null;
  final diagnosis = e.requestOptions.extra[networkDiagnosisKey];
  return diagnosis is NetworkDiagnosis
      ? '$_unreachable\n\nRef: ${diagnosis.summary}'
      : _unreachable;
}
