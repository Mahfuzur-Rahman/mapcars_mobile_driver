import 'dart:async';

/// Serializes anything that can raise an OS permission dialog.
///
/// Android shows one runtime-permission dialog per activity. A second
/// `requestPermissions()` issued while one is already on screen is dropped, and
/// its result arrives with an empty `grantResults` array. geolocator's Android
/// handler treats that as "the user cancelled" and returns *without* invoking
/// either its result or its error callback — so the Dart `Future` never
/// completes and whatever awaited it waits forever.
///
/// That is not hypothetical. On a fresh install, signing in fires the FCM
/// notification prompt at the same moment the first map asks for location; the
/// location request lost the race, and the map sat on its "Finding your
/// location…" spinner for the rest of the session.
///
/// Every call site that can prompt goes through [request], so the dialogs queue
/// instead of colliding.
class PermissionGate {
  PermissionGate._();

  /// Tail of the queue — completes when the in-flight prompt is done.
  static Future<void> _tail = Future<void>.value();

  /// A prompt the user simply never answers must not wedge the queue for the
  /// life of the process, so each slot gives up its turn after this.
  static const _slotTimeout = Duration(minutes: 2);

  /// Runs [prompt] once every earlier caller has finished, and returns its
  /// result. Throws [TimeoutException] if it hasn't settled within [timeout] —
  /// callers are expected to treat that as "not granted". [timeout] is only
  /// passed explicitly by tests, which can't sit out the real two minutes.
  static Future<T> request<T>(
    Future<T> Function() prompt, {
    Duration timeout = _slotTimeout,
  }) {
    final slot = Completer<T>();
    final previous = _tail;

    // Claim the next turn synchronously. Two callers in the same tick must see
    // different predecessors, which they wouldn't if this were awaited first.
    _tail = slot.future.then<void>((_) {}, onError: (_) {});

    unawaited(Future<void>(() async {
      await previous;
      try {
        slot.complete(await prompt().timeout(timeout));
      } catch (error, stack) {
        if (!slot.isCompleted) slot.completeError(error, stack);
      }
    }));

    return slot.future;
  }
}
