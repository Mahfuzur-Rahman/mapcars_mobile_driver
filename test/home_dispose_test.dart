// Leaving the Home screen must stop the dispatch board, and must not throw.
//
// flutter_riverpod 2.6 asserts the element is mounted on every `ref` use, and
// by `State.dispose()` it is not — so `ref.read(...)` inside `dispose()` threw
// a StateError every time Home was left. `stop()` therefore never ran (the
// board's socket and poll kept going mid-trip, raising "New ride request"
// alerts for a driver already carrying a passenger) and each navigation away
// logged a FlutterError to Crashlytics.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/auth/providers/driver_approval_provider.dart';
import 'package:mapcars_driver/src/features/drive/presentation/home_screen.dart';
import 'package:mapcars_driver/src/features/drive/providers/dispatch_board_controller.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';

/// Records `stop()` instead of touching a socket.
class _RecordingBoard extends DispatchBoardController {
  _RecordingBoard(super.ref);

  int stopCalls = 0;

  @override
  Future<void> stop() async => stopCalls++;
}

/// `_resumeActiveTrip` runs from `initState`; with no active trip it simply
/// returns, leaving the screen where it is.
class _NoTripsService extends TripService {
  _NoTripsService() : super(Dio());

  @override
  Future<Trip?> getActive() async => null;

  @override
  Future<List<Trip>> mine() async => const [];
}

void main() {
  testWidgets('leaving Home stops the dispatch board without throwing',
      (tester) async {
    late _RecordingBoard board;
    final container = ProviderContainer(overrides: [
      tripServiceProvider.overrideWithValue(_NoTripsService()),
      driverApprovalProvider
          .overrideWith((ref) async => DriverApproval.unknown),
      dispatchBoardProvider.overrideWith((ref) => board = _RecordingBoard(ref)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DriverHomeScreen()),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Home should mount cleanly');

    // Remove Home from the tree — what any navigation away from it does.
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SizedBox()),
    ));

    expect(tester.takeException(), isNull,
        reason: 'dispose() must not use ref after the element is unmounted');
    expect(board.stopCalls, 1, reason: 'the board must be stopped on leave');
  });

  test('stop() is a safe no-op once the board has itself been disposed', () async {
    // The provider is app-scoped, so Home normally leaves first; but if the
    // whole scope is torn down at the same time the captured notifier is
    // already disposed when Home's dispose() calls stop().
    final container = ProviderContainer();
    final board = container.read(dispatchBoardProvider.notifier);
    container.dispose();

    await expectLater(board.stop(), completes);
  });
}
