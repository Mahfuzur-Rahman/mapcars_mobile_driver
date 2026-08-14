/// The pricing config served by the API (`GET /api/v1/fare-chart`), as much of it
/// as the driver app needs: the platform commission that determines take-home.
///
/// Full chart shape lives in the API (api/src/Mapcars.Application/Pricing/Models)
/// and the customer app; the driver only computes earnings, so this is a lean
/// view of the same document.
class FareChart {
  const FareChart({
    required this.version,
    required this.currency,
    required this.driverFeePercent,
  });

  final int version;
  final String currency;

  /// MAP CARS commission as a percent of the fare (e.g. 15).
  final double driverFeePercent;

  factory FareChart.fromJson(Map<String, dynamic> j) {
    final platform = j['platform'];
    final feePct = platform is Map<String, dynamic>
        ? (platform['driverFeePercent'] as num?)?.toDouble() ?? 0
        : 0.0;
    return FareChart(
      version: (j['version'] as num?)?.toInt() ?? 0,
      currency: (j['currency'] ?? 'GBP') as String,
      driverFeePercent: feePct,
    );
  }

  /// Platform fee on a fare, in pence.
  int platformFeePence(int farePence) => (farePence * driverFeePercent / 100).round();

  /// Driver take-home for a fare (before tips), in pence.
  int driverEarningsPence(int farePence) => farePence - platformFeePence(farePence);
}
