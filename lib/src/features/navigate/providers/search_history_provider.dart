import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_notifier.dart';
import '../models/place.dart';
import '../services/search_history_service.dart';

/// Exposes the current driver's recent destinations and lets the search screen
/// record new ones. Rebuilds whenever the signed-in driver changes, so recents
/// always belong to the active user (and reset to `guest` on sign-out).
class SearchHistoryNotifier extends StateNotifier<List<Place>> {
  SearchHistoryNotifier(this._service, this._userId)
      : super(_service.recents(_userId));

  final SearchHistoryService _service;
  final String? _userId;

  Future<void> add(Place place) async {
    state = await _service.add(_userId, place);
  }

  Future<void> clear() async {
    await _service.clear(_userId);
    state = const [];
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<Place>>((ref) {
  final service = ref.watch(searchHistoryServiceProvider);
  final userId = ref.watch(authNotifierProvider.select((s) => s.userId));
  return SearchHistoryNotifier(service, userId);
});
