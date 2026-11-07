import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/messages_service.dart';
import 'chat_inbox.dart';

@immutable
class ChatThreadState {
  const ChatThreadState({
    this.conversation,
    this.messages = const [],
    this.loading = true,
    this.error = false,
    this.closed = false,
  });

  final Conversation? conversation;
  final List<ChatMessage> messages;
  final bool loading;
  final bool error;

  /// A send came back 409 — the chat closed while it was open.
  final bool closed;

  bool get canSend => !closed && (conversation?.canSend ?? false);

  ChatThreadState copyWith({
    Conversation? conversation,
    List<ChatMessage>? messages,
    bool? loading,
    bool? error,
    bool? closed,
  }) =>
      ChatThreadState(
        conversation: conversation ?? this.conversation,
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        error: error ?? this.error,
        closed: closed ?? this.closed,
      );
}

/// One trip's conversation. Live messages come from [ChatInbox.arrivals], so it
/// works the same for the active trip (SignalR) and a past one (FCM).
class ChatThreadNotifier extends StateNotifier<ChatThreadState> {
  ChatThreadNotifier(this._ref, this.tripId) : super(const ChatThreadState()) {
    _sub = _ref
        .read(chatInboxProvider)
        .arrivals
        .where((m) => m.tripId == tripId)
        .listen(_append);
  }

  final Ref _ref;
  final String tripId;
  StreamSubscription<ChatMessage>? _sub;

  MessagesService get _service => _ref.read(messagesServiceProvider);

  Future<void> load() async {
    if (mounted) state = state.copyWith(loading: true, error: false);
    try {
      final conversation = _service.get(tripId);
      final messages = _service.messages(tripId);
      final c = await conversation;
      final m = await messages;
      if (!mounted) return;
      // Keep anything that arrived live during the fetch.
      final ids = m.map((x) => x.id).toSet();
      state = state.copyWith(
        conversation: c,
        messages: [...m, ...state.messages.where((x) => !ids.contains(x.id))],
        loading: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[chat] load failed: $e');
      if (mounted) state = state.copyWith(loading: false, error: true);
    }
  }

  Future<void> send(String text) async {
    try {
      _append(await _service.send(tripId, text));
    } on ChatClosedException {
      if (mounted) state = state.copyWith(closed: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[chat] send failed: $e');
    }
  }

  void _append(ChatMessage message) {
    if (!mounted || state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final chatThreadProvider = StateNotifierProvider.autoDispose
    .family<ChatThreadNotifier, ChatThreadState, String>(
  (ref, tripId) => ChatThreadNotifier(ref, tripId),
);
