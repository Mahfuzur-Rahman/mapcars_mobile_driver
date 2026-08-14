import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/fare_chart.dart';

/// Fetches and caches the pricing config from the API (`GET /api/v1/fare-chart`).
///
/// The driver app uses it to compute earnings (fare − platform fee) so the
/// commission rate and take-home always reflect the current chart, not a
/// hardcoded percentage. Cached for the session; public endpoint (no auth).
final fareChartProvider = FutureProvider<FareChart>((ref) async {
  final dio = ref.watch(dioProvider);
  return apiCall(() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/fare-chart');
    return FareChart.fromJson(res.data!);
  });
});
