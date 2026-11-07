import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// The chat has closed (24 h after the trip, or the trip was cancelled). The API
/// answers a send with 409; the chat screen swaps its composer for a notice.
class ChatClosedException implements Exception {
  const ChatClosedException();
}

/// Everything chat-related the app asks the API for.
class MessagesService {
  MessagesService(this._dio);
  final Dio _dio;

  static const _conversations = '/api/v1/conversations';

  Future<List<Conversation>> list() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>(_conversations);
        return (res.data ?? [])
            .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<Conversation> get(String tripId) => apiCall(() async {
        final res =
            await _dio.get<Map<String, dynamic>>('$_conversations/$tripId');
        return Conversation.fromJson(res.data!);
      });

  Future<UnreadSummary> unread() => apiCall(() async {
        final res =
            await _dio.get<Map<String, dynamic>>('$_conversations/unread');
        return UnreadSummary.fromJson(res.data ?? const {});
      });

  Future<void> markRead(String tripId) => apiCall(() async {
        await _dio.post<void>('$_conversations/$tripId/read');
      });

  Future<List<ChatMessage>> messages(String tripId) => apiCall(() async {
        final res =
            await _dio.get<List<dynamic>>('/api/v1/trips/$tripId/messages');
        return (res.data ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<ChatMessage> send(String tripId, String content) async {
    try {
      return await apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/v1/trips/$tripId/messages',
          data: {'content': content},
        );
        return ChatMessage.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      if (e.statusCode == 409) throw const ChatClosedException();
      rethrow;
    }
  }
}

final messagesServiceProvider =
    Provider<MessagesService>((ref) => MessagesService(ref.watch(dioProvider)));
