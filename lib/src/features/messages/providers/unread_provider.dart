import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/messages_service.dart';

/// Unread chat messages, per trip. The server is the truth ([UnreadNotifier.refresh]
/// on sign-in and every resume); [UnreadNotifier.bump] is the live increment
/// between refreshes.
@immutable
class UnreadState {
  const UnreadState({this.byTrip = const {}});

  final Map<String, int> byTrip;

  int get total => byTrip.values.fold(0, (a, b) => a + b);

  int forTrip(String? tripId) => tripId == null ? 0 : (byTrip[tripId] ?? 0);

  UnreadState bump(String tripId) =>
      UnreadState(byTrip: {...byTrip, tripId: forTrip(tripId) + 1});

  UnreadState clear(String tripId) => byTrip.containsKey(tripId)
      ? UnreadState(byTrip: Map.of(byTrip)..remove(tripId))
      : this;
}

class UnreadNotifier extends StateNotifier<UnreadState> {
  UnreadNotifier(this._service) : super(const UnreadState());

  /// Looked up per call, not at construction: a badge must be able to render
  /// (in every screen that shows one) without building Dio and its config.
  final MessagesService Function() _service;

  /// Re-reads the counts. Silent on failure: the badge keeps its last value.
  Future<void> refresh() async {
    try {
      final summary = await _service().unread();
      if (mounted) state = UnreadState(byTrip: summary.byTrip);
    } catch (e) {
      if (kDebugMode) debugPrint('[unread] refresh failed: $e');
    }
  }

  void bump(String tripId) => state = state.bump(tripId);

  void clear(String tripId) => state = state.clear(tripId);

  /// Sign-out: the next account must not inherit these badges.
  void reset() => state = const UnreadState();
}

// `read` at call time, never `watch`: a token refresh rebuilds Dio, and that
// must not wipe the badges.
final unreadProvider = StateNotifierProvider<UnreadNotifier, UnreadState>(
  (ref) => UnreadNotifier(() => ref.read(messagesServiceProvider)),
);
