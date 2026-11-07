import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat_alert.dart';
import '../chat_party.dart';
import '../models/chat_message.dart';
import '../services/messages_service.dart';
import 'unread_provider.dart';

enum IncomingChat { ignore, readNow, unread }

/// What an arriving message means for the badge. Pure, so it is tested.
IncomingChat classifyIncoming(ChatMessage message, {required String? openTripId}) {
  if (message.senderType != kOtherParty) return IncomingChat.ignore; // own echo
  if (message.tripId == openTripId) return IncomingChat.readNow;
  return IncomingChat.unread;
}

/// The one place an incoming chat message is handled, whichever channel brought
/// it: SignalR `messageReceived` (active trip) or a foreground FCM push (any
/// trip). The same message often arrives on both, so it de-duplicates by id —
/// otherwise the badge would count it twice and the banner would fire twice.
class ChatInbox {
  ChatInbox(this._ref);

  final Ref _ref;
  // A Set literal is insertion-ordered, so `first` is the oldest id.
  final _seen = <String>{};
  final _arrivals = StreamController<ChatMessage>.broadcast();

  /// Every new message, for an open chat thread to append.
  Stream<ChatMessage> get arrivals => _arrivals.stream;

  /// The trip whose chat is on screen, or null. Set by `ChatScreen`.
  String? openTripId;

  void receive(ChatMessage message, {String? senderName}) {
    if (!_seen.add(message.id)) return;
    if (_seen.length > 200) _seen.remove(_seen.first);

    _arrivals.add(message);

    switch (classifyIncoming(message, openTripId: openTripId)) {
      case IncomingChat.ignore:
        return;
      case IncomingChat.readNow:
        unawaited(_markRead(message.tripId));
      case IncomingChat.unread:
        _ref.read(unreadProvider.notifier).bump(message.tripId);
        unawaited(showChatAlert(_ref, message, senderName));
    }
  }

  Future<void> _markRead(String tripId) async {
    try {
      await _ref.read(messagesServiceProvider).markRead(tripId);
    } catch (e) {
      // Self-heals: the next open of this chat marks it read again.
      if (kDebugMode) debugPrint('[chat] markRead failed: $e');
    }
  }

  void dispose() => _arrivals.close();
}

final chatInboxProvider = Provider<ChatInbox>((ref) {
  final inbox = ChatInbox(ref);
  ref.onDispose(inbox.dispose);
  return inbox;
});
