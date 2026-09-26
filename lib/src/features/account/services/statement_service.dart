import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/statement.dart';

/// The driver's weekly statements — built by the API about an hour after each
/// UK week closes. Read-only: nothing here moves money.
class StatementService {
  StatementService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/drivers/me/statements';

  /// `GET /drivers/me/statements` — newest first.
  Future<List<Statement>> list() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>(_base);
        return (res.data ?? [])
            .map((e) => Statement.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// `GET /drivers/me/statements/{id}` — the summary plus one line per trip.
  Future<StatementDetail> get(String id) => apiCall(() async {
        final res = await _dio
            .get<Map<String, dynamic>>('$_base/${Uri.encodeComponent(id)}');
        return StatementDetail.fromJson(res.data!);
      });
}

final statementServiceProvider = Provider<StatementService>(
  (ref) => StatementService(ref.watch(dioProvider)),
);

final statementsProvider = FutureProvider.autoDispose<List<Statement>>(
  (ref) => ref.watch(statementServiceProvider).list(),
);

final statementDetailProvider =
    FutureProvider.autoDispose.family<StatementDetail, String>(
  (ref, id) => ref.watch(statementServiceProvider).get(id),
);
