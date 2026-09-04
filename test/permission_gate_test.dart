// The permission queue.
//
// Android shows one runtime-permission dialog at a time: a request raised while
// another is already on screen is dropped, and geolocator answers that dropped
// result by never completing its Future at all. On a fresh install that turned
// the first map into a permanent "Finding your location…" spinner, because the
// FCM notification prompt fires at sign-in in the same moment the map asks for
// location.
//
// These pin the three properties that stop it recurring: prompts never overlap,
// a prompt that throws still hands the queue on, and a prompt nobody ever
// answers gives up its turn instead of wedging everything behind it.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/permissions/permission_gate.dart';

void main() {
  test('prompts never overlap, even when queued in the same tick', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final dialogs = <Completer<String>>[];

    Future<String> prompt() {
      final dialog = Completer<String>();
      dialogs.add(dialog);
      maxInFlight = ++inFlight > maxInFlight ? inFlight : maxInFlight;
      return dialog.future.whenComplete(() => inFlight--);
    }

    // Three callers queuing synchronously — exactly the collision this exists
    // to prevent, and the one the real bug hit.
    final results = [
      PermissionGate.request(prompt),
      PermissionGate.request(prompt),
      PermissionGate.request(prompt),
    ];

    for (var i = 0; i < 3; i++) {
      await pumpEventQueue();
      expect(dialogs.length, i + 1,
          reason: 'prompt $i should be the only one on screen');
      dialogs[i].complete('answer $i');
    }

    expect(await Future.wait(results), ['answer 0', 'answer 1', 'answer 2']);
    expect(maxInFlight, 1);
  });

  test('a prompt that throws still hands the queue on', () async {
    await expectLater(
      PermissionGate.request<String>(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(await PermissionGate.request(() async => 'granted'), 'granted');
  });

  test('an unanswered prompt gives up its turn rather than wedging the queue',
      () async {
    const slot = Duration(milliseconds: 200);

    // Never completes — the user walked away from the dialog.
    final abandoned = PermissionGate.request<String>(
      () => Completer<String>().future,
      timeout: slot,
    );
    final next = PermissionGate.request(() async => 'granted', timeout: slot);

    await expectLater(abandoned, throwsA(isA<TimeoutException>()));
    expect(await next, 'granted');
  });
}
