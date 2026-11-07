import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/messages/chat_party.dart';
import 'package:mapcars_driver/src/features/messages/models/chat_message.dart';
import 'package:mapcars_driver/src/features/messages/models/conversation.dart';
import 'package:mapcars_driver/src/features/messages/presentation/conversation_tile.dart';

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

  group('chatTimeLabel', () {
    final now = DateTime(2026, 11, 7, 15, 30);
    test('today shows the time', () {
      expect(chatTimeLabel(DateTime(2026, 11, 7, 9, 5).toUtc(), now), '09:05');
    });
    test('yesterday says so', () {
      expect(chatTimeLabel(DateTime(2026, 11, 6, 22).toUtc(), now), 'Yesterday');
    });
    test('older shows the date', () {
      expect(chatTimeLabel(DateTime(2026, 10, 30, 8).toUtc(), now), '30 Oct');
    });
  });

  group('previewText', () {
    test('prefixes my own last message', () {
      expect(
        previewText(ConversationPreview(
            content: 'On my way', senderType: kMe, sentAtUtc: DateTime.utc(2026))),
        'You: On my way',
      );
    });
    test('shows theirs as is', () {
      expect(
        previewText(ConversationPreview(
            content: "I'm outside",
            senderType: kOtherParty,
            sentAtUtc: DateTime.utc(2026))),
        "I'm outside",
      );
    });
  });

  group('ConversationTile', () {
    Conversation convo() => Conversation.fromJson({
          'tripId': 't1',
          'counterpartName': 'Ahmed Ali',
          'pickupAddress': 'Heathrow T5',
          'dropoffAddress': 'Soho Square',
          'tripStatus': 'Completed',
          'tripDateUtc': '2026-11-03T10:00:00Z',
          'lastMessage': {
            'content': 'Left my umbrella',
            'senderType': kOtherParty,
            'sentAtUtc': '2026-11-03T11:00:00Z',
          },
          'unreadCount': 0,
          'canSend': false,
        });

    Future<void> pump(WidgetTester tester, int unread) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationTile(conversation: convo(), unread: unread),
            ),
          ),
        );

    testWidgets('shows name, route and preview', (tester) async {
      await pump(tester, 0);
      expect(find.text('Ahmed Ali'), findsOneWidget);
      expect(find.text('Heathrow T5 → Soho Square'), findsOneWidget);
      expect(find.text('Left my umbrella'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('an unread conversation shows its count', (tester) async {
      await pump(tester, 2);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('caps the count at 9+', (tester) async {
      await pump(tester, 14);
      expect(find.text('9+'), findsOneWidget);
    });
  });
}
