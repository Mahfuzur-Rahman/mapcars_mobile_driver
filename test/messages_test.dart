import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/messages/models/chat_message.dart';
import 'package:mapcars_driver/src/features/messages/models/conversation.dart';

void main() {
  group('Conversation.fromJson', () {
    final json = {
      'tripId': 't1',
      'counterpartName': 'Ahmed Ali',
      'pickupAddress': 'Heathrow T5, Hounslow TW6',
      'dropoffAddress': 'Soho Square, London',
      'tripStatus': 'Completed',
      'tripDateUtc': '2026-11-03T10:00:00Z',
      'lastMessage': {
        'content': 'Left my umbrella',
        'senderType': 'rider',
        'sentAtUtc': '2026-11-03T11:00:00Z',
      },
      'unreadCount': 2,
      'canSend': true,
    };

    test('parses every field', () {
      final c = Conversation.fromJson(json);
      expect(c.tripId, 't1');
      expect(c.counterpartName, 'Ahmed Ali');
      expect(c.unreadCount, 2);
      expect(c.canSend, isTrue);
      expect(c.lastMessage!.content, 'Left my umbrella');
      expect(c.tripDateUtc.isUtc, isTrue);
    });

    test('folds the legacy rider spelling onto customer', () {
      expect(Conversation.fromJson(json).lastMessage!.senderType, 'customer');
    });

    test('a conversation with no messages has no preview', () {
      final c = Conversation.fromJson({...json, 'lastMessage': null});
      expect(c.lastMessage, isNull);
    });

    test('routeLabel uses the first part of each address', () {
      expect(Conversation.fromJson(json).routeLabel, 'Heathrow T5 → Soho Square');
    });
  });

  group('UnreadSummary.fromJson', () {
    test('keeps the per-trip counts', () {
      final s = UnreadSummary.fromJson({
        'total': 3,
        'trips': [
          {'tripId': 'a', 'count': 1},
          {'tripId': 'b', 'count': 2},
        ],
      });
      expect(s.byTrip, {'a': 1, 'b': 2});
      expect(s.total, 3);
    });
  });

  group('ChatMessage.fromPushData', () {
    final data = {
      'type': 'messageReceived',
      'tripId': 't1',
      'messageId': 'm1',
      'senderType': 'driver',
      'senderId': 's1',
      'content': "I'm outside",
      'sentAtUtc': '2026-11-07T12:00:00.0000000Z',
    };

    test('builds a message from a full push', () {
      final m = ChatMessage.fromPushData(data)!;
      expect(m.id, 'm1');
      expect(m.tripId, 't1');
      expect(m.content, "I'm outside");
      expect(m.sentAtUtc, DateTime.utc(2026, 11, 7, 12));
    });

    test('returns null for a push from an older API without the message', () {
      expect(
          ChatMessage.fromPushData({'type': 'messageReceived', 'tripId': 't1'}),
          isNull);
    });
  });
}
