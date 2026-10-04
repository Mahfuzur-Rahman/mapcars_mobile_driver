// The driving flow's primary action must always be reachable — big, at the
// bottom, never under the system bar, and without scrolling anything.
//
// Every screen here is a map with a sheet over it, and a driver uses them in a
// car mount with a thumb. Before the sheet had a pinned footer the buttons were
// the last children of the sheet's body: on a small phone with the 3-button nav
// bar up, or with larger text, they were clipped, under the nav bar, or one
// scroll away. These tests put each real screen on a 360x640 phone with a 48dp
// nav bar at text scale 1.0, 1.3 and 2.0 and demand the buttons are on screen and
// tappable as the screen stands.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapcars_driver/src/core/network/api_client.dart';
import 'package:mapcars_driver/src/core/theme/app_theme.dart';
import 'package:mapcars_driver/src/core/widgets/countdown.dart';
import 'package:mapcars_driver/src/core/widgets/mc.dart';
import 'package:mapcars_driver/src/features/account/providers/driver_trips_provider.dart';
import 'package:mapcars_driver/src/features/auth/providers/driver_approval_provider.dart';
import 'package:mapcars_driver/src/features/drive/presentation/arrived_screen.dart';
import 'package:mapcars_driver/src/features/drive/presentation/driving_screen.dart';
import 'package:mapcars_driver/src/features/drive/presentation/home_screen.dart';
import 'package:mapcars_driver/src/features/drive/presentation/nav_pickup_screen.dart';
import 'package:mapcars_driver/src/features/drive/presentation/request_preview_screen.dart';
import 'package:mapcars_driver/src/features/drive/presentation/widgets/request_card.dart';
import 'package:mapcars_driver/src/features/drive/providers/dispatch_board_controller.dart';
import 'package:mapcars_driver/src/features/drive/providers/driver_location_reporting_controller.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';
import 'package:mapcars_driver/src/features/navigate/models/directions_result.dart';
import 'package:mapcars_driver/src/features/navigate/models/place.dart';
import 'package:mapcars_driver/src/features/navigate/presentation/route_preview_screen.dart';
import 'package:mapcars_driver/src/features/navigate/services/maps_service.dart';

import 'support/fake_platforms.dart';
import 'support/reachability.dart';

// --- fixtures ---------------------------------------------------------------

Trip _trip({
  String method = 'Cash',
  String? pin = '4821',
  String pickup = '221B Baker Street, Marylebone, London NW1 6XE',
  String dropoff = 'Heathrow Airport Terminal 5, Longford TW6 2GA',
}) =>
    Trip.fromJson({
      'id': 't1',
      'status': 'InProgress',
      'pickupAddress': pickup,
      'dropoffAddress': dropoff,
      'pickupLat': 51.5,
      'pickupLng': -0.1,
      'dropoffLat': 51.6,
      'dropoffLng': -0.2,
      'createdAtUtc': '2026-09-01T12:00:00Z',
      'fareAmount': 42.5,
      'tipAmount': 2,
      'distanceMiles': 14.2,
      'tier': 'standard',
      'paymentMethod': method,
      'paymentStatus': 'Pending',
      if (pin != null) 'pin': pin,
      'customer': {'name': 'Alexandria Montgomery-Smith', 'rating': 4.8},
      'expiresAtUtc':
          DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
    });

/// Answers the calls a screen makes on mount with nothing to report.
class _QuietTrips extends TripService {
  _QuietTrips() : super(Dio());

  @override
  Future<Trip?> getActive() async => null;

  @override
  Future<List<Trip>> mine() async => const [];
}

/// No sockets, no polling.
class _QuietBoard extends DispatchBoardController {
  _QuietBoard(super.ref);

  @override
  Future<void> start(double lat, double lng) async {}

  @override
  Future<void> stop() async {}
}

/// No GPS stream, no 5-second push timer.
class _QuietReporting extends DriverLocationReportingController {
  _QuietReporting(super.ref);

  @override
  void start() {}
}

class _FakeMapsService extends GoogleMapsService {
  @override
  Future<DirectionsResult> directions({
    required LatLng origin,
    required LatLng destination,
  }) async =>
      DirectionsResult(
        points: [origin, destination],
        distanceText: '4.3 mi',
        durationText: '12 mins',
        distanceMeters: 6900,
        durationSeconds: 720,
        bounds: LatLngBounds(southwest: origin, northeast: destination),
      );
}

/// What the real service says for every Dio error (maps_service.dart
/// `_networkMessage`) - the in-car banner text. Two lines at 1.0 text, and
/// three at 2.0 before the banner caps it.
const _realMapsError =
    "Couldn't reach the maps service. Check your connection.";

class _FailingMapsService extends GoogleMapsService {
  @override
  Future<DirectionsResult> directions({
    required LatLng origin,
    required LatLng destination,
  }) async =>
      throw const MapsServiceException(_realMapsError);
}

final _overrides = <Override>[
  tripServiceProvider.overrideWithValue(_QuietTrips()),
  apiHealthProvider.overrideWith((ref) async => true),
  // A real 1-second timer would outlive the test.
  secondTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
  driverTripsProvider.overrideWith((ref) async => const <Trip>[]),
  dispatchBoardProvider.overrideWith((ref) => _QuietBoard(ref)),
  driverLocationReportingProvider.overrideWith((ref) => _QuietReporting(ref)),
];

Widget _app(Widget home, {List<Override> extra = const []}) => ProviderScope(
      overrides: [..._overrides, ...extra],
      // The real theme: it selects Nunito, whose metrics decide what fits.
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

Override _approval(DriverApproval a) =>
    driverApprovalProvider.overrideWith((ref) async => a);

Finder _btn(String label) => find.widgetWithText(McButton, label);
Finder _ghost(String label) => find.widgetWithText(McGhostButton, label);
Finder _danger(String label) => find.widgetWithText(McDangerButton, label);

/// Settles the one-frame-late things (approval hydration, post-frame callbacks).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    group('driving flow, text x$scale', () {
      testWidgets('home: "Go online" is reachable', (tester) async {
        installFakeMapAndLocation();
        await pumpOnSmallPhone(
          tester,
          _app(const DriverHomeScreen(), extra: [
            _approval(const DriverApproval(status: 'Approved', isOnline: false)),
          ]),
          textScale: scale,
        );
        await _settle(tester);

        expectReachableWithoutScrolling(tester, _btn('Go online'));
      });

      testWidgets(
          'home: "Go offline" is reachable with the payment-restriction note up',
          (tester) async {
        installFakeMapAndLocation();
        await pumpOnSmallPhone(
          tester,
          _app(const DriverHomeScreen(), extra: [
            // Online + cash-only: the sheet's longest state — a 2-line status
            // plus the restriction note.
            _approval(const DriverApproval(status: 'Approved', isOnline: true)),
          ]),
          textScale: scale,
        );
        await _settle(tester);

        expect(find.textContaining("cash only"), findsOneWidget,
            reason: 'the restriction note is what makes this state tall');
        expectReachableWithoutScrolling(tester, _btn('Go offline'));
      });

      testWidgets('home: "Check status" is reachable when not approved',
          (tester) async {
        installFakeMapAndLocation();
        await pumpOnSmallPhone(
          tester,
          _app(const DriverHomeScreen(), extra: [
            _approval(
                const DriverApproval(status: 'PendingApproval', isOnline: false)),
          ]),
          textScale: scale,
        );
        await _settle(tester);

        expectReachableWithoutScrolling(tester, _btn('Check status'));
      });

      testWidgets('request card: Accept and Ignore are reachable',
          (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RequestCard(
                trip: _trip(),
                busy: false,
                moreCount: 3,
                onAccept: () {},
                onIgnore: () {},
              ),
            ),
          )),
          textScale: scale,
        );

        expectReachableWithoutScrolling(tester, _btn('Accept'));
        expectReachableWithoutScrolling(tester, _ghost('Ignore'));
      });

      testWidgets('request card: the expired state keeps Dismiss reachable',
          (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RequestCard(
                trip: _trip(),
                busy: false,
                moreCount: 0,
                expired: true,
                onAccept: () {},
                onIgnore: () {},
              ),
            ),
          )),
          textScale: scale,
        );

        expectReachableWithoutScrolling(tester, _btn('Expired'));
        expectReachableWithoutScrolling(tester, _ghost('Dismiss'));
      });

      testWidgets('arrived: Start trip and Cancel job are reachable with the '
          'PIN pad showing', (tester) async {
        installFakeMapAndLocation();
        await pumpOnSmallPhone(
          tester,
          _app(ArrivedScreen(trip: _trip())),
          textScale: scale,
        );
        await _settle(tester);

        expect(find.text("Confirm customer's PIN"), findsOneWidget,
            reason: 'the PIN pad is what makes this sheet tall');
        expectReachableWithoutScrolling(tester, _btn('Start trip'));
        expectReachableWithoutScrolling(tester, _danger('Cancel job'));
      });

      testWidgets('driving: Complete trip is reachable with the drop-off '
          'payment banner up', (tester) async {
        installFakeMapAndLocation();
        await pumpOnSmallPhone(
          tester,
          _app(DrivingScreen(trip: _trip(method: 'Cash'))),
          textScale: scale,
        );
        await _settle(tester);

        expect(find.textContaining('£'), findsWidgets);
        expectReachableWithoutScrolling(tester, _btn('Complete trip'));
        expectReachableWithoutScrolling(tester, _ghost('Message passenger'));
      });

      testWidgets('nav pickup: "I\'ve arrived" and Cancel job are reachable',
          (tester) async {
        installFakeMapAndLocation();
        await pumpOnSmallPhone(
          tester,
          _app(NavPickupScreen(trip: _trip())),
          textScale: scale,
        );
        await _settle(tester);

        expectReachableWithoutScrolling(tester, _btn("I've arrived"));
        expectReachableWithoutScrolling(tester, _danger('Cancel job'));
      });

      testWidgets('request preview: the empty state keeps its buttons '
          'reachable', (tester) async {
        installFakeMapAndLocation();
        await pumpOnSmallPhone(
          tester,
          _app(const RequestPreviewScreen()),
          textScale: scale,
        );
        await _settle(tester);

        expectReachableWithoutScrolling(tester, _btn('Go to home'));
      });

      testWidgets('route preview: Done is reachable', (tester) async {
        installFakeMapAndLocation(fix: _fix);
        await pumpOnSmallPhone(
          tester,
          _app(
            const RoutePreviewScreen(destination: _place),
            extra: [googleMapsServiceProvider.overrideWithValue(_FakeMapsService())],
          ),
          textScale: scale,
        );
        await _settle(tester);

        expect(find.text('12 mins'), findsOneWidget);
        expectReachableWithoutScrolling(tester, _btn('Done'));
      });

      testWidgets('route preview: Try again is reachable on a route error',
          (tester) async {
        installFakeMapAndLocation(); // permission denied -> error state
        await pumpOnSmallPhone(
          tester,
          _app(const RoutePreviewScreen(destination: _place)),
          textScale: scale,
        );
        await _settle(tester);

        expectReachableWithoutScrolling(tester, _btn('Try again'));
      });
    });
  }
  // The map's own overlays - the Re-centre pill and the route-error banner.
  // They used to be pinned 14dp from the bottom of the map (behind the sheet);
  // then, stacked above the sheet in a column with no top bound, they could be
  // pushed up under the floating nav / ETA banner or into the status bar. They
  // must now sit between the top controls and the sheet, whole, and be tappable.
  for (final scale in [1.0, 1.3, 2.0]) {
    group('live route map overlays, text x$scale', () {
      final screens = <String, ({
        Widget Function(Trip) build,
        String primary,
        Finder? etaText,
      })>{
        'nav pickup': (
          build: (t) => NavPickupScreen(trip: t),
          primary: "I've arrived",
          etaText: find.textContaining('to pickup'),
        ),
        'arrived': (
          build: (t) => ArrivedScreen(trip: t),
          primary: 'Start trip',
          etaText: null,
        ),
        'driving': (
          build: (t) => DrivingScreen(trip: t),
          primary: 'Complete trip',
          etaText: find.textContaining('to drop-off'),
        ),
      };

      // (pan the map, fail the route) for pill-only, banner-only and both.
      const scenarios = <String, (bool, bool)>{
        'pill only': (true, false),
        'banner only': (false, true),
        'pill and banner together': (true, true),
      };

      for (final screen in screens.entries) {
        for (final scenario in scenarios.entries) {
          testWidgets('${screen.key}, ${scenario.key}: overlays sit whole '
              'between the top controls and the sheet', (tester) async {
            final (pan, fail) = scenario.value;
            final map = installFakeMapAndLocation(fix: _fix);
            await pumpOnSmallPhone(
              tester,
              _app(screen.value.build(_trip()), extra: [
                googleMapsServiceProvider.overrideWithValue(
                    fail ? _FailingMapsService() : _FakeMapsService()),
              ]),
              textScale: scale,
            );
            await _settle(tester);
            if (pan) {
              map.userPans();
              await _settle(tester);
            }

            final width =
                tester.view.physicalSize.width / tester.view.devicePixelRatio;
            Rect boxOf(Finder text) => tester.getRect(
                find.ancestor(of: text, matching: find.byType(Container)).first);

            // The floating controls this screen draws along the top.
            final controls = <String, Rect>{
              for (final e in find.byType(McMenuButton).evaluate())
                'menu button': tester.getRect(find.byWidget(e.widget)),
              if (find.byType(McFloatingNav).evaluate().isNotEmpty)
                'floating nav': tester.getRect(find.byType(McFloatingNav)),
              if (screen.value.etaText != null)
                'ETA banner': boxOf(screen.value.etaText!),
            };
            expect(controls, isNotEmpty);
            final sheet = tester.getRect(find.byType(McSheet));

            final overlays = <String, Rect>{};
            final pill = find.text('Re-centre');
            final banner = find.text(_realMapsError);
            // At huge text with the banner up the pill yields to the sheet's
            // footer; at 1.0 / 1.3 it must always be there when panned.
            final pillMayYield = scale > 1.3 && fail;
            final pillShown = pill.evaluate().isNotEmpty;
            if (!pan) expect(pillShown, isFalse);
            if (pan && !pillMayYield) expect(pillShown, isTrue);
            expect(banner.evaluate().isNotEmpty, fail);
            if (pillShown) overlays['Re-centre pill'] = boxOf(pill);
            if (fail) overlays['route-error banner'] = boxOf(banner);

            for (final o in overlays.entries) {
              final r = o.value;
              expect(r.top, greaterThanOrEqualTo(0),
                  reason: '${o.key} $r starts above the screen');
              expect(r.left, greaterThanOrEqualTo(0));
              expect(r.right, lessThanOrEqualTo(width));
              expect(r.bottom, lessThanOrEqualTo(sheet.top + 0.01),
                  reason: '${o.key} $r is not above the sheet $sheet');
              for (final c in controls.entries) {
                expect(r.overlaps(c.value), isFalse,
                    reason: '${o.key} $r runs under the ${c.key} ${c.value}');
              }
            }
            if (overlays.length == 2) {
              expect(
                  overlays['Re-centre pill']!
                      .overlaps(overlays['route-error banner']!),
                  isFalse);
            }
            for (final c in controls.entries) {
              expect(sheet.overlaps(c.value), isFalse,
                  reason: 'the sheet $sheet runs under the ${c.key} ${c.value}');
            }

            // Tappable across the whole pill, not just at its centre.
            if (pillShown) {
              final pillTap = find
                  .ancestor(of: pill, matching: find.byType(GestureDetector))
                  .first;
              for (final at in const [
                Alignment(-0.9, 0),
                Alignment.center,
                Alignment(0.9, 0),
                Alignment(0, -0.9),
                Alignment(0, 0.9),
              ]) {
                expect(pillTap.hitTestable(at: at), findsOneWidget,
                    reason: 'the Re-centre pill is covered at $at');
              }
            }
            if (fail) {
              expect(banner.hitTestable(), findsOneWidget);
            }

            // However much the overlays take, the sheet shrinks - its footer
            // stays on screen.
            expectReachableWithoutScrolling(tester, _btn(screen.value.primary));

            if (pillShown) {
              await tester.tap(pill);
              await _settle(tester);
              expect(find.text('Re-centre'), findsNothing,
                  reason: 'tapping it hands the camera back to follow mode');
            }
          });
        }
      }
    });
  }

  // The sheet is bounded twice if both LiveRouteMap (the space under the top
  // controls and overlays) and McSheet (85% of what it is given) cap it - the
  // second cap wastes ~15% of the free space and, with the route-error banner
  // and the pill up at huge text, pushed "Complete trip" under the nav bar.
  group('live route map sheet is bounded once', () {
    testWidgets('driving, both overlays, text x2.0: Complete trip is '
        'reachable and nothing overflows', (tester) async {
      final map = installFakeMapAndLocation(fix: _fix);
      await pumpOnSmallPhone(
        tester,
        _app(DrivingScreen(trip: _trip()), extra: [
          googleMapsServiceProvider.overrideWithValue(_FailingMapsService()),
        ]),
        textScale: 2.0,
      );
      await _settle(tester);
      map.userPans();
      await _settle(tester);

      expect(find.text(_realMapsError), findsOneWidget);
      expectReachableWithoutScrolling(tester, _btn('Complete trip'));
    });

    testWidgets('arrived, text x1.0, no overlays: the sheet may use all the '
        'space under the floating nav (no dead band)', (tester) async {
      installFakeMapAndLocation(fix: _fix);
      await pumpOnSmallPhone(
        tester,
        _app(ArrivedScreen(trip: _trip()), extra: [
          googleMapsServiceProvider.overrideWithValue(_FakeMapsService()),
        ]),
      );
      await _settle(tester);

      // The top block is the nav and its own padding; the sheet gets all of
      // the screen below it.
      final topBlock = tester.getRect(find
          .ancestor(
              of: find.byType(McFloatingNav), matching: find.byType(Padding))
          .first);
      final sheet = tester.getRect(find.byType(McSheet));
      // The PIN-pad sheet is taller than the free space on a 640dp phone, so
      // it must grow right up to the controls - not stop 15% (~79dp) short.
      expect(sheet.top - topBlock.bottom, lessThan(1.0),
          reason: 'sheet top ${sheet.top} leaves a '
              '${sheet.top - topBlock.bottom}dp dead band under the controls '
              '(bottom ${topBlock.bottom})');
      expectReachableWithoutScrolling(tester, _btn('Start trip'));
    });
  });

  // The status label in the home top bar must be readable, not cut to "...".
  group('home status label', () {
    final states = <String, DriverApproval>{
      'Offline': const DriverApproval(status: 'Approved', isOnline: false),
      'Online': const DriverApproval(status: 'Approved', isOnline: true),
      'Not approved':
          const DriverApproval(status: 'PendingApproval', isOnline: false),
    };
    for (final e in states.entries) {
      testWidgets('"${e.key}" is not truncated at text x1.0 on 360dp',
          (tester) async {
        installFakeMapAndLocation();
        await pumpOnSmallPhone(
          tester,
          _app(const DriverHomeScreen(), extra: [_approval(e.value)]),
        );
        await _settle(tester);

        // The top-bar pill's label (the sheet may repeat some of these words).
        final label = find.byWidgetPredicate(
            (w) => w is Text && w.data == e.key && w.style?.fontSize == 14);
        expect(label, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse);
        final laid = paragraph.size.width;
        final wanted = paragraph.getMaxIntrinsicWidth(double.infinity);
        expect(laid, greaterThanOrEqualTo(wanted - 0.5),
            reason: '"${e.key}" got ${laid}dp but needs ${wanted}dp');
      });
    }
  });
}

const _place = Place(
    label: 'Tower Bridge',
    address: 'Tower Bridge Rd, London SE1 2UP',
    lat: 51.5055,
    lng: -0.0754);

final _fix = Position(
  latitude: 51.5,
  longitude: -0.12,
  timestamp: DateTime(2026, 9, 1),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);
