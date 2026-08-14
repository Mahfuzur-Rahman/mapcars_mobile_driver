import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/prefs.dart';
import '../models/place.dart';

/// Per-user recent-search history, stored on-device (SharedPreferences).
///
/// This is view/UX convenience data, not business data — so it never touches
/// the API or Postgres (see the project's "mobile owns no business data" rule).
/// History is keyed by driver id, so two drivers sharing a phone don't see each
/// other's recents. If cross-device sync is ever needed, this becomes a cache
/// in front of an API endpoint without changing callers.
class SearchHistoryService {
  SearchHistoryService(this._prefs);

  final SharedPreferences _prefs;

  /// How many recent destinations to keep (most-recent first).
  static const int maxEntries = 5;

  String _key(String? userId) =>
      'search_history_${(userId == null || userId.isEmpty) ? 'guest' : userId}';

  /// The driver's recent destinations, most-recent first. Empty if none/corrupt.
  List<Place> recents(String? userId) {
    final raw = _prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      // Corrupt payload — drop it rather than crash the search screen.
      return const [];
    }
  }

  /// Records [place] as the newest recent, de-duping the same spot and trimming
  /// to [maxEntries]. Returns the updated list so callers can update state.
  Future<List<Place>> add(String? userId, Place place) async {
    final next = recents(userId).where((p) => !_sameSpot(p, place)).toList()
      ..insert(0, place);
    final trimmed = next.take(maxEntries).toList(growable: false);
    await _prefs.setString(
      _key(userId),
      jsonEncode(trimmed.map((p) => p.toJson()).toList()),
    );
    return trimmed;
  }

  Future<void> clear(String? userId) => _prefs.remove(_key(userId));

  /// Two results are the "same spot" if their label+address match or their
  /// coordinates are effectively identical (guards against tiny float drift).
  bool _sameSpot(Place a, Place b) =>
      (a.label == b.label && a.address == b.address) ||
      ((a.lat - b.lat).abs() < 1e-6 && (a.lng - b.lng).abs() < 1e-6);
}

final searchHistoryServiceProvider = Provider<SearchHistoryService>(
  (ref) => SearchHistoryService(ref.watch(sharedPreferencesProvider)),
);
