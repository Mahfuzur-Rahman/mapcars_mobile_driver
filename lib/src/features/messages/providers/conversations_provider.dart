import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import '../services/messages_service.dart';

/// The Messages list. Re-fetched on pull-to-refresh and on return from a chat.
final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>(
  (ref) => ref.read(messagesServiceProvider).list(),
);
