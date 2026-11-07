// The unread-message rule and its badge.
//
// Chat was previously invisible until opened: a driver asking "which entrance?"
// got silence unless the customer happened to look. These pin the ways that
// could go wrong in the other direction — badging your own messages, badging a
// conversation you are already reading, or losing count across trips.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/widgets/mc.dart';
import 'package:mapcars_driver/src/features/messages/chat_party.dart';
import 'package:mapcars_driver/src/features/messages/models/chat_message.dart';
import 'package:mapcars_driver/src/features/messages/providers/chat_inbox.dart';
import 'package:mapcars_driver/src/features/messages/providers/unread_provider.dart';

ChatMessage _msg(String senderType) => ChatMessage(
      id: 'm1',
      tripId: 't1',
      senderType: senderType,
      senderId: 's1',
      content: 'Which entrance?',
      sentAtUtc: DateTime.utc(2026, 9, 1, 12),
    );

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('classifyIncoming', () {
    test("the other party's message is unread when its chat is not open", () {
      expect(classifyIncoming(_msg(kOtherParty), openTripId: null),
          IncomingChat.unread);
      expect(classifyIncoming(_msg(kOtherParty), openTripId: 'another-trip'),
          IncomingChat.unread);
    });

    test('it is read on arrival while that chat is on screen', () {
      expect(classifyIncoming(_msg(kOtherParty), openTripId: 't1'),
          IncomingChat.readNow);
    });

    test('my own message (the echo of a send) is never unread', () {
      expect(classifyIncoming(_msg(kMe), openTripId: null), IncomingChat.ignore);
    });
  });

  group('UnreadState', () {
    test('bump counts per trip and totals across trips', () {
      final s = const UnreadState().bump('a').bump('a').bump('b');
      expect(s.forTrip('a'), 2);
      expect(s.forTrip('b'), 1);
      expect(s.total, 3);
    });

    test('clear drops one trip only', () {
      final s = const UnreadState().bump('a').bump('b').clear('a');
      expect(s.forTrip('a'), 0);
      expect(s.total, 1);
    });

    test('an unknown or null trip has nothing unread', () {
      expect(const UnreadState().forTrip(null), 0);
      expect(const UnreadState().forTrip('x'), 0);
    });
  });

  group('McBadge', () {
    testWidgets('draws nothing at zero', (tester) async {
      await tester.pumpWidget(
        _host(const McBadge(count: 0, child: Text('Message passenger'))),
      );

      expect(find.text('Message passenger'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows the count', (tester) async {
      await tester.pumpWidget(
        _host(const McBadge(count: 3, child: Text('Message passenger'))),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('caps at 9+ so the bubble cannot grow unbounded',
        (tester) async {
      await tester.pumpWidget(
        _host(const McBadge(count: 42, child: Text('Message passenger'))),
      );

      expect(find.text('9+'), findsOneWidget);
      expect(find.text('42'), findsNothing);
    });

    testWidgets('the bubble itself is not announced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(McBadge(
          count: 3,
          child: McGhostButton(
            'Message passenger',
            semanticLabel: 'Message passenger, 3 unread',
            onTap: () {},
          ),
        )),
      );

      // A bare "3" read out beside a button is not information — the count
      // reaches the reader through the button's own label instead.
      expect(find.bySemanticsLabel('3'), findsNothing);
      final node = tester.getSemantics(find.byType(McGhostButton));
      expect(node.label, 'Message passenger, 3 unread');
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);

      handle.dispose();
    });
  });
}
