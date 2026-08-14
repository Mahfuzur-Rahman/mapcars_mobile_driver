import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Talks to `POST /api/v1/trips/{tripId}/ratings` — a driver rating the rider
/// once a trip is `Completed`. Mirrors `DriverAuthService`'s thin-service shape.
class RatingService {
  RatingService(this._dio);
  final Dio _dio;

  Future<void> rateTrip(String tripId, {required int score, String? comment}) =>
      apiCall(() async {
        await _dio.post<void>(
          '/api/v1/trips/$tripId/ratings',
          data: {
            'score': score,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          },
        );
      });
}

final ratingServiceProvider = Provider<RatingService>(
  (ref) => RatingService(ref.watch(dioProvider)),
);
