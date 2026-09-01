// The driver's dispatch board — the screen their income comes through.
//
// Requests are first-come-wins, so the two things that must not regress are:
// a job the driver waved away never reappearing, and losing an accept race
// clearing the job off the board instead of leaving a dead card that 400s.
//
// The board's network paths (SignalR pushes, the poll) need a live socket and
// aren't covered here; what is covered is every state transition that happens
// after the data arrives.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/network/api_exception.dart';
import 'package:mapcars_driver/src/features/drive/providers/dispatch_board_controller.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';

Trip _trip(String id) => Trip(
      id: id,
      pickupAddress: 'Pickup $id',
      pickupLat: 51.5,
      pickupLng: -0.12,
      dropoffAddress: 'Dropoff $id',
      dropoffLat: 51.51,
      dropoffLng: -0.13,
      status: TripStatus.requested,
      fareAmount: 12.5,
      createdAtUtc: DateTime.utc(2026, 9, 1),
    );

/// Lets a test put trips on the board without a live socket or a poll — the
/// board is normally only ever filled by those two.
class _SeedableBoard extends DispatchBoardController {
  _SeedableBoard(super.ref);

  void seed(List<Trip> trips) => state = DispatchBoardState(trips: trips);
}

class _FakeTripService extends TripService {
  _FakeTripService({this.result, this.error}) : super(Dio());

  final Trip? result;
  final Object? error;
  final List<String> accepted = [];

  @override
  Future<Trip> accept(String tripId) async {
    accepted.add(tripId);
    if (error != null) throw error!;
    return result!;
  }
}

({ProviderContainer container, _SeedableBoard board}) _harness(
    TripService service) {
  final container = ProviderContainer(overrides: [
    tripServiceProvider.overrideWithValue(service),
    dispatchBoardProvider.overrideWith((ref) => _SeedableBoard(ref)),
  ]);
  addTearDown(container.dispose);
  final board =
      container.read(dispatchBoardProvider.notifier) as _SeedableBoard;
  return (container: container, board: board);
}

List<String> _ids(ProviderContainer c) =>
    c.read(dispatchBoardProvider).trips.map((t) => t.id).toList();

void main() {
  group('ignore', () {
    test('takes the job off the board and remembers it', () {
      final h = _harness(_FakeTripService());
      h.board.seed([_trip('a'), _trip('b')]);

      h.board.ignore('a');

      expect(_ids(h.container), ['b']);
      expect(h.board.isIgnored('a'), isTrue);
      expect(h.board.isIgnored('b'), isFalse);
    });

    test('remembers a job that was never on this board', () {
      // The /request one-shot screen fetches outside this controller, so a
      // driver can decline a job the board has not seen. If that did not stick,
      // the next poll would hand it straight back.
      final h = _harness(_FakeTripService());
      h.board.seed([_trip('a')]);

      h.board.ignore('ghost');

      expect(h.board.isIgnored('ghost'), isTrue);
      expect(_ids(h.container), ['a'], reason: 'board otherwise untouched');
    });
  });

  group('bringToFront', () {
    test('moves the tapped job to the top without dropping any', () {
      final h = _harness(_FakeTripService());
      h.board.seed([_trip('a'), _trip('b'), _trip('c')]);

      h.board.bringToFront('c');

      expect(_ids(h.container), ['c', 'a', 'b']);
    });

    test('is a no-op for the first job or one not on the board', () {
      final h = _harness(_FakeTripService());
      h.board.seed([_trip('a'), _trip('b')]);

      h.board.bringToFront('a');
      expect(_ids(h.container), ['a', 'b']);

      h.board.bringToFront('nope');
      expect(_ids(h.container), ['a', 'b']);
    });
  });

  group('accept', () {
    test('returns the trip and clears it off the board', () async {
      final won = _trip('a');
      final service = _FakeTripService(result: won);
      final h = _harness(service);
      h.board.seed([_trip('a'), _trip('b')]);

      final result = await h.board.accept('a');

      expect(result?.id, 'a');
      expect(service.accepted, ['a']);
      expect(_ids(h.container), ['b']);
      expect(h.container.read(dispatchBoardProvider).busyTripId, isNull,
          reason: 'the spinner must not outlive the accept');
    });

    test('losing the race drops the job and surfaces the reason', () async {
      // First-come-wins: another driver got there first and the API says 400.
      // Leaving the card up would let the driver keep tapping a dead job.
      final service = _FakeTripService(
        error: ApiException(
            message: 'That request is no longer available.', statusCode: 400),
      );
      final h = _harness(service);
      h.board.seed([_trip('a'), _trip('b')]);

      final result = await h.board.accept('a');

      expect(result, isNull);
      expect(_ids(h.container), ['b']);
      expect(h.container.read(dispatchBoardProvider).error,
          'That request is no longer available.');
      expect(h.container.read(dispatchBoardProvider).busyTripId, isNull);
    });

    test('a non-API failure still clears the job, with a readable message',
        () async {
      final service = _FakeTripService(error: StateError('socket died'));
      final h = _harness(service);
      h.board.seed([_trip('a')]);

      final result = await h.board.accept('a');

      expect(result, isNull);
      expect(_ids(h.container), isEmpty);
      // Never a raw exception toString in front of a driver.
      expect(h.container.read(dispatchBoardProvider).error,
          'That request is no longer available.');
    });
  });
}
