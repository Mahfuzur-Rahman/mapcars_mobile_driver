// Notification tap routing.
//
// A tap is the driver's most direct instruction — "show me that" — and the two
// ways it goes wrong are both silent: routing to a screen with nothing behind
// it (a dead trip, a blank chat), or navigating before the session has been
// restored on a cold start and being overwritten by the splash's own "go home".
// The rule and the hold-until-ready queue are pinned here; the navigation
// itself is thin glue over routes the router already guards.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/notifications/push_tap.dart';

Matcher _board(String id) =>
    isA<OpenRequestsBoard>().having((t) => t.tripId, 'tripId', id);
Matcher _cancelled(String id) =>
    isA<OpenCancelledTrip>().having((t) => t.tripId, 'tripId', id);
Matcher _chat(String id) =>
    isA<OpenTripChat>().having((t) => t.tripId, 'tripId', id);
Matcher _appeal(String id) =>
    isA<OpenTierAppeal>().having((t) => t.appealId, 'appealId', id);
final _justOpen = isA<JustOpenApp>();

void main() {
  group('pushTapFor', () {
    test('a new request opens the board, never the trip itself', () {
      expect(pushTapFor({'type': 'tripAvailable', 'tripId': 't1'}), _board('t1'));
    });

    test('a customer cancellation routes as a cancelled trip', () {
      expect(
        pushTapFor({
          'type': 'tripStatus',
          'tripId': 't1',
          'status': 'CancelledByCustomer',
        }),
        _cancelled('t1'),
      );
    });

    test('status casing does not matter', () {
      expect(
        pushTapFor({
          'type': 'tripStatus',
          'tripId': 't1',
          'status': 'cancelledbycustomer',
        }),
        _cancelled('t1'),
      );
    });

    test('a non-cancellation status change just opens the app', () {
      expect(
        pushTapFor({'type': 'tripStatus', 'tripId': 't1', 'status': 'InProgress'}),
        _justOpen,
      );
      expect(pushTapFor({'type': 'tripStatus', 'tripId': 't1'}), _justOpen);
    });

    test('a chat message opens that trip\'s chat', () {
      expect(pushTapFor({'type': 'messageReceived', 'tripId': 't9'}), _chat('t9'));
    });

    test('a tier appeal decision opens the appeal', () {
      expect(
        pushTapFor({
          'type': 'tier_appeal_decision',
          'appealId': 'a1',
          'status': 'Approved',
        }),
        _appeal('a1'),
      );
      // Tolerates the camelCase spelling the rest of the payload types use.
      expect(
        pushTapFor({'type': 'tierAppealDecision', 'appealId': 'a1'}),
        _appeal('a1'),
      );
    });

    test('missing or blank ids never produce a route', () {
      expect(pushTapFor({'type': 'tripAvailable'}), _justOpen);
      expect(pushTapFor({'type': 'tripAvailable', 'tripId': '  '}), _justOpen);
      expect(pushTapFor({'type': 'messageReceived', 'tripId': ''}), _justOpen);
      expect(
        pushTapFor({'type': 'tripStatus', 'status': 'CancelledByCustomer'}),
        _justOpen,
      );
      expect(pushTapFor({'type': 'tier_appeal_decision'}), _justOpen);
    });

    test('unknown, missing or odd types just open the app', () {
      expect(pushTapFor({'type': 'somethingNew', 'tripId': 't1'}), _justOpen);
      expect(pushTapFor({'tripId': 't1'}), _justOpen);
      expect(pushTapFor({}), _justOpen);
      expect(pushTapFor({'type': 42, 'tripId': null}), _justOpen);
    });

    test('non-string ids are read, not crashed on', () {
      expect(pushTapFor({'type': 'messageReceived', 'tripId': 7}), _chat('7'));
    });
  });

  group('PushTapDispatcher', () {
    late List<PushTap> opened;
    late bool signedIn;
    late PushTapDispatcher dispatcher;

    setUp(() {
      opened = [];
      signedIn = true;
      dispatcher = PushTapDispatcher(
        isSignedIn: () => signedIn,
        open: (tap) async {
          opened.add(tap);
          return true;
        },
      );
    });

    test('a cold-start tap waits for the session, then opens once', () async {
      expect(await dispatcher.tap(const OpenTripChat('t1')), isFalse);
      expect(opened, isEmpty, reason: 'must not race the session restore');

      expect(await dispatcher.sessionReady(), isTrue);
      expect(opened, [_chat('t1')]);

      // Consumed: a second ready (splash revisited) does not replay it.
      expect(await dispatcher.sessionReady(), isFalse);
      expect(opened, hasLength(1));
    });

    test('only the latest held tap survives', () async {
      await dispatcher.tap(const OpenRequestsBoard('old'));
      await dispatcher.tap(const OpenTripChat('new'));
      await dispatcher.sessionReady();
      expect(opened, [_chat('new')]);
    });

    test('ready with nothing held lets the splash route as normal', () async {
      expect(await dispatcher.sessionReady(), isFalse);
      expect(opened, isEmpty);
    });

    test('once ready, taps open immediately', () async {
      await dispatcher.sessionReady();
      expect(await dispatcher.tap(const OpenTierAppeal('a1')), isTrue);
      expect(opened, [_appeal('a1')]);
    });

    test('signed out: nothing opens, including a held tap', () async {
      signedIn = false;
      await dispatcher.tap(const OpenTripChat('t1'));
      expect(await dispatcher.sessionReady(), isFalse);
      expect(await dispatcher.tap(const OpenRequestsBoard('t2')), isFalse);
      expect(opened, isEmpty);
    });

    test('JustOpenApp never navigates', () async {
      await dispatcher.sessionReady();
      expect(await dispatcher.tap(const JustOpenApp()), isFalse);
      expect(opened, isEmpty);
    });

    test('a failing route is swallowed, not thrown', () async {
      final failing = PushTapDispatcher(
        isSignedIn: () => true,
        open: (_) async => throw StateError('router gone'),
      );
      await failing.sessionReady();
      expect(await failing.tap(const OpenTripChat('t1')), isFalse);
    });
  });
}
