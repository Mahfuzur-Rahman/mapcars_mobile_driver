// Full-page screens (forms, onboarding, trip complete) pin their primary action
// in an McActionBar, so it is always on screen - above the keyboard, never under
// the system nav bar, and without a scroll.
//
// Before, each of these had its button as the last child of a scroll view: on a
// 360x640 phone with a 48dp nav bar, with the keyboard up, or at larger text,
// the driver had to scroll to find "Continue" / "Submit for review" / "Back
// online". Every screen is pumped for real on that phone, with Nunito, at text
// scale 1.0 and 1.3 (and with the keyboard open where it has fields).
//
// Flutter fails any test that logs an exception, so a RenderFlex overflow in
// these screens fails them by itself.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mapcars_driver/src/core/network/api_exception.dart';
import 'package:mapcars_driver/src/core/theme/app_theme.dart';
import 'package:mapcars_driver/src/core/widgets/driver_tab_bar.dart';
import 'package:mapcars_driver/src/core/widgets/mc.dart';
import 'package:mapcars_driver/src/features/account/presentation/edit_profile_screen.dart';
import 'package:mapcars_driver/src/features/account/presentation/profile_screen.dart';
import 'package:mapcars_driver/src/features/account/presentation/settings_screen.dart';
import 'package:mapcars_driver/src/features/account/presentation/vehicle_form_screen.dart';
import 'package:mapcars_driver/src/features/account/presentation/vehicle_tier_screen.dart';
import 'package:mapcars_driver/src/features/account/services/vehicle_service.dart';
import 'package:mapcars_driver/src/features/auth/models/auth_state.dart';
import 'package:mapcars_driver/src/features/auth/providers/auth_notifier.dart';
import 'package:mapcars_driver/src/features/auth/services/driver_auth_service.dart';
import 'package:mapcars_driver/src/features/drive/models/fare_chart.dart';
import 'package:mapcars_driver/src/features/drive/presentation/trip_complete_screen.dart';
import 'package:mapcars_driver/src/features/drive/providers/fare_chart_provider.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';
import 'package:mapcars_driver/src/features/navigate/models/place.dart';
import 'package:mapcars_driver/src/features/navigate/presentation/set_route_screen.dart';
import 'package:mapcars_driver/src/features/navigate/services/search_history_service.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/documents_screen.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/email_login_screen.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/email_signup_screen.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/email_verify_screen.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/registration_screen.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/under_review_screen.dart';
import 'package:mapcars_driver/src/features/onboarding/presentation/verify_screen.dart';
import 'package:mapcars_driver/src/features/onboarding/services/driver_documents_service.dart';

import 'support/fake_platforms.dart';
import 'support/reachability.dart';

// --- fakes & fixtures -------------------------------------------------------

DriverProfile _profile({
  String? first = 'James',
  String? last = 'Kowalski',
  String? nationalId = 'QQ123456C',
}) =>
    DriverProfile(
      driverId: 'd1',
      firstName: first,
      lastName: last,
      fullName: [first, last].whereType<String>().join(' '),
      nationalIdNumber: nationalId,
      hasProfilePicture: false,
      isProfileComplete: true,
    );

class _FakeAuth extends DriverAuthService {
  _FakeAuth(this.profile, {this.hold, this.failWith}) : super(Dio());

  final DriverProfile profile;

  /// When set, [getProfile] waits for it - a slow network.
  final Future<void>? hold;

  /// When set, [updateProfile] throws it - a failed save.
  final Object? failWith;
  final List<String> updates = [];

  @override
  Future<DriverProfile> getProfile() async {
    await hold;
    return profile;
  }

  @override
  Future<DriverProfile> updateProfile({
    required String firstName,
    required String lastName,
    String? email,
    DateTime? dateOfBirth,
    String? address,
    required String nationalIdNumber,
    String? drivingLicenceNumber,
    String? passportNumber,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? marketingConsent,
  }) async {
    if (failWith != null) throw failWith!;
    updates.add('$firstName|$lastName|$nationalIdNumber');
    return profile;
  }
}

class _FakeDocs extends DriverDocumentsService {
  _FakeDocs(this.docs) : super(Dio());
  final List<DriverDocument> docs;

  @override
  Future<List<DriverDocument>> list() async => docs;
}

DriverDocument _doc(
  String type, {
  String name = 'document.pdf',
  String status = 'Pending',
  bool deletion = false,
  DateTime? expires,
}) =>
    DriverDocument(
      id: '$type-$name',
      type: type,
      originalFileName: name,
      reviewStatus: status,
      createdAtUtc: DateTime(2026, 9, 1),
      expiresOn: expires,
      isDeletionRequested: deletion,
    );

/// A driver with no trips on file.
class _QuietTrips extends TripService {
  _QuietTrips() : super(Dio());

  @override
  Future<List<Trip>> mine() async => const [];
}

class _FakeVehicles extends VehicleService {
  _FakeVehicles({this.vehicle, this.appeals = const []}) : super(Dio());
  final Vehicle? vehicle;
  final List<TierAppeal> appeals;

  @override
  Future<Vehicle?> getMine() async => vehicle;

  @override
  Future<List<TierAppeal>> getAppeals() async => appeals;
}

const _vehicle = Vehicle(
  id: 'v1',
  make: 'Toyota',
  model: 'Prius',
  year: 2022,
  colour: 'Silver',
  registrationNumber: 'AB12 CDE',
  tier: 'economy',
);

TierAppeal _appeal(String status, {String reason = 'Full leather interior'}) =>
    TierAppeal(
      id: 'a-$status',
      driverId: 'd1',
      vehicleId: 'v1',
      currentTier: 'economy',
      requestedTier: 'comfort',
      reason: reason,
      photoUrls: const [],
      status: status,
      createdAtUtc: DateTime(2026, 9, 1),
    );

Trip _completedTrip() => Trip.fromJson({
      'id': 't1',
      'status': 'Completed',
      'pickupAddress': '221B Baker Street, London NW1 6XE',
      'dropoffAddress': 'Heathrow Airport Terminal 5, TW6 2GA',
      'pickupLat': 51.5,
      'pickupLng': -0.1,
      'dropoffLat': 51.6,
      'dropoffLng': -0.2,
      'createdAtUtc': '2026-09-01T12:00:00Z',
      'fareAmount': 42.5,
      'platformFeeAmount': 6.38,
      'driverEarnings': 36.12,
      'tipAmount': 2,
      'tier': 'standard',
      'paymentMethod': 'Cash',
      'paymentStatus': 'Paid',
      'customer': {'name': 'Alexandria Montgomery-Smith', 'rating': 4.8},
    });

/// [auth] is always faked: the real auth notifier reads the API client, which
/// needs the app's dotenv to be loaded.
Widget _app(Widget home,
        {_FakeAuth? auth, List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [
        driverAuthServiceProvider
            .overrideWithValue(auth ?? _FakeAuth(_profile())),
        ...overrides,
      ],
      // The real theme: it selects Nunito, whose metrics decide what fits.
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

/// The auth notifier with a pending email sign-up, as the verify screen finds
/// it. [resendEmailOtp] only counts, so no network is needed.
class _VerifyAuth extends AuthNotifier {
  _VerifyAuth(super.service, super.ref, {String? error}) {
    state = AuthState(email: 'driver@example.com', error: error);
  }

  int resends = 0;

  @override
  Future<bool> resendEmailOtp(String email) async {
    resends++;
    return true;
  }
}

class _VerifyAuthHolder {
  _VerifyAuthHolder({this.error});
  final String? error;
  late final _VerifyAuth notifier;
}

Widget _verifyApp(_VerifyAuthHolder holder) => _app(
      const EmailVerifyScreen(),
      overrides: [
        authNotifierProvider.overrideWith((ref) => holder.notifier =
            _VerifyAuth(ref.watch(driverAuthServiceProvider), ref,
                error: holder.error)),
      ],
    );

Finder _btn(String label) => find.widgetWithText(McButton, label);

/// Lets async loads (profile, documents) land; not pumpAndSettle, because a
/// spinner or a blinking cursor never settles.
Future<void> _load(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Tap a field, as the driver does, then raise the keyboard. [target] is what
/// gets tapped when it is not the first TextField - e.g. the OtpInput, whose
/// real TextField is hidden under its own tap target.
Future<void> _focusFirstField(WidgetTester tester, [Finder? target]) async {
  if (target == null) {
    await tester.ensureVisible(find.byType(TextField).first);
  }
  await tester.tap(target ?? find.byType(TextField).first);
  await tester.pump();
  await showKeyboard(tester);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final scale in const [1.0, 1.3]) {
    group('text x$scale', () {
      // --- Documents -------------------------------------------------------
      testWidgets('documents: "Submit for review" is reachable without '
          'scrolling', (tester) async {
        // Worst-case chip rows: a long status, an expiry, a long file name.
        final docs = [
          _doc('PhvLicence',
              name: 'phv-driver-licence-2026-final-scan.pdf',
              deletion: true,
              expires: DateTime(2027, 12, 31)),
          _doc('VehicleInsurance',
              status: 'Rejected', expires: DateTime(2027, 12, 31)),
          _doc('DbsCheck', status: 'Approved', expires: DateTime(2027, 1, 1)),
        ];
        await pumpOnSmallPhone(
          tester,
          _app(const DocumentsScreen(), overrides: [
            driverDocumentsServiceProvider.overrideWithValue(_FakeDocs(docs)),
          ]),
          textScale: scale,
        );
        await _load(tester);

        expect(find.text('Deletion Requested'), findsOneWidget,
            reason: 'the widest status chip is what overflowed at 360dp');
        expectReachableWithoutScrolling(tester, _btn('Submit for review'));
      });

      // --- Registration + Edit profile (shared DriverProfileForm) ----------
      testWidgets('registration: "Continue" is reachable, also with the '
          'keyboard open', (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(const RegistrationScreen()),
          textScale: scale,
        );
        await _load(tester);
        expectReachableWithoutScrolling(tester, _btn('Continue'));

        await _focusFirstField(tester);
        expectReachableWithoutScrolling(tester, _btn('Continue'));
      });

      testWidgets('edit profile: "Save changes" is reachable, also with the '
          'keyboard open', (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(const EditProfileScreen()),
          textScale: scale,
        );
        await _load(tester);
        expectReachableWithoutScrolling(tester, _btn('Save changes'));

        await _focusFirstField(tester);
        expectReachableWithoutScrolling(tester, _btn('Save changes'));
      });

      // --- Vehicle form ----------------------------------------------------
      testWidgets('vehicle form: "Save vehicle" is reachable, also with the '
          'keyboard open', (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(const VehicleFormScreen()),
          textScale: scale,
        );
        expectReachableWithoutScrolling(tester, _btn('Save vehicle'));

        await _focusFirstField(tester);
        expectReachableWithoutScrolling(tester, _btn('Save vehicle'));
      });

      // --- Trip complete ---------------------------------------------------
      testWidgets('trip complete: "Back online" is reachable, also with the '
          'comment keyboard open; the rating stays together in the body',
          (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(TripCompleteScreen(trip: _completedTrip()), overrides: [
            // Never answers: the screen falls back to the default 15% fee.
            fareChartProvider
                .overrideWith((ref) => Completer<FareChart>().future),
          ]),
          textScale: scale,
        );
        await tester.pump();

        expectReachableWithoutScrolling(tester, _btn('Back online'));

        // Rating, comment and Submit rating are one block in the scrolling
        // body - not pinned with Back online.
        expect(find.text('Submit rating'), findsOneWidget);
        expect(
            find.ancestor(
                of: find.text('Submit rating'),
                matching: find.byType(McActionBar)),
            findsNothing);
        expect(
            find.ancestor(
                of: find.byType(TextField),
                matching: find.byType(McActionBar)),
            findsNothing);

        await _focusFirstField(tester);
        expectReachableWithoutScrolling(tester, _btn('Back online'));
      });

      testWidgets('trip complete: with the comment keyboard up, "Submit '
          'rating" is scrolled above the pinned bar, not hidden behind it',
          (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(TripCompleteScreen(trip: _completedTrip()), overrides: [
            fareChartProvider
                .overrideWith((ref) => Completer<FareChart>().future),
          ]),
          textScale: scale,
        );
        await tester.pump();

        // Focus as a driver would; the field's own scroll-into-view runs (no
        // test-side ensureVisible after the keyboard is up).
        final field = find.byType(TextField).first;
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pump();
        await showKeyboard(tester);
        await tester.pump(const Duration(milliseconds: 600));

        expectReachableWithoutScrolling(
            tester, find.widgetWithText(McGhostButton, 'Submit rating'));
        final submit =
            tester.getRect(find.widgetWithText(McGhostButton, 'Submit rating'));
        final bar = tester.getRect(find.byType(McActionBar));
        expect(submit.bottom, lessThanOrEqualTo(bar.top + 0.01),
            reason: '"Submit rating" $submit is behind the pinned bar $bar');
      });

      // --- Under review ----------------------------------------------------
      testWidgets('under review: nothing overflows and "Continue to home" is '
          'reachable', (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(const UnderReviewScreen(), overrides: [
            driverDocumentsServiceProvider.overrideWithValue(_FakeDocs([
              _doc('PhvLicence', status: 'Approved'),
              _doc('VehicleInsurance', status: 'Rejected'),
              _doc('DbsCheck'),
            ])),
          ]),
          textScale: scale,
        );
        await _load(tester);

        expect(find.text('Under review'), findsWidgets);
        expectReachableWithoutScrolling(tester, _btn('Continue to home'));
        expectReachableWithoutScrolling(
            tester, find.widgetWithText(McGhostButton, 'My documents'));
        // Support is a link in the body, still on the screen.
        expect(find.text('Support'), findsOneWidget);
      });

      // --- Verify (login) / Sign up ---------------------------------------
      testWidgets('verify (phone): "Send code" is reachable with the keyboard '
          'open', (tester) async {
        await pumpOnSmallPhone(tester, _app(const VerifyScreen()),
            textScale: scale);
        expectReachableWithoutScrolling(tester, _btn('Send code'));

        await _focusFirstField(tester);
        expectReachableWithoutScrolling(tester, _btn('Send code'));
      });

      testWidgets('verify (email, autofocus): "Sign in" is reachable with the '
          'keyboard open', (tester) async {
        await pumpOnSmallPhone(tester, _app(const EmailLoginScreen()),
            textScale: scale, keyboardOpen: true);
        await tester.pump(const Duration(milliseconds: 300));

        expectReachableWithoutScrolling(tester, _btn('Sign in'));
      });

      testWidgets('verify: the two tabs are the same height, so the active '
          'pill does not jump when switching', (tester) async {
        await pumpOnSmallPhone(tester, _app(const VerifyScreen()),
            textScale: scale);
        double heightOf(String label) => tester
            .getRect(find
                .ancestor(of: find.text(label), matching: find.byType(Container))
                .first)
            .height;
        expect(heightOf('Phone number'), heightOf('Email & password'));
      });

      testWidgets('verify: Google and "Sign up" stay in the scrolling body',
          (tester) async {
        await pumpOnSmallPhone(tester, _app(const VerifyScreen()),
            textScale: scale);
        for (final label in const ['Sign up']) {
          expect(
              find.ancestor(
                  of: _btn(label), matching: find.byType(McActionBar)),
              findsNothing);
        }
        expect(
            find.ancestor(
                of: find.text('Continue with Google'),
                matching: find.byType(McActionBar)),
            findsNothing);
      });

      testWidgets('sign up (phone): "Continue" is reachable with the keyboard '
          'open', (tester) async {
        await pumpOnSmallPhone(tester, _app(const EmailSignupScreen()),
            textScale: scale, keyboardOpen: true);
        await tester.pump(const Duration(milliseconds: 300));

        expectReachableWithoutScrolling(tester, _btn('Continue'));
      });

      testWidgets('sign up (email): "Create account" is reachable with the '
          'keyboard open', (tester) async {
        await pumpOnSmallPhone(
            tester,
            _app(const EmailSignupScreen(initialMethod: SignupMethod.email)),
            textScale: scale,
            keyboardOpen: true);
        await tester.pump(const Duration(milliseconds: 300));

        expectReachableWithoutScrolling(tester, _btn('Create account'));
      });

      // --- Verify email: the live action is the pinned one -----------------
      // While the code is live, "Verify" is pinned. Once it expires, "Verify"
      // can do nothing, so "Resend code" - which used to be a link in the
      // scroll body, behind a dead-looking pinned button - takes its place.
      testWidgets('verify email: "Verify" is pinned while the code is live, '
          '"Resend code" once it expires (keyboard open)', (tester) async {
        final auth = _VerifyAuthHolder();
        await pumpOnSmallPhone(tester, _verifyApp(auth), textScale: scale);
        await tester.pump();
        await _focusFirstField(tester, find.byType(OtpInput));

        expect(find.text('Code expires in 3:00'), findsWidgets);
        expectReachableWithoutScrolling(tester, _btn('Verify'));
        expect(_btn('Resend code'), findsNothing);

        await tester.pump(const Duration(seconds: 181));

        expect(find.text('Code expired'), findsOneWidget);
        expectReachableWithoutScrolling(tester, _btn('Resend code'));
        // The dead "Verify" is gone, not left looking enabled.
        expect(_btn('Verify'), findsNothing);
        // The countdown text stays in the content, not in the bar.
        expect(
            find.ancestor(
                of: find.text('Code expired'),
                matching: find.byType(McActionBar)),
            findsNothing);

        // And it works: tapping it asks for a new code and the pinned action
        // goes back to "Verify".
        await tester.tap(_btn('Resend code'));
        await tester.pump();
        expect(auth.notifier.resends, 1);
        expect(find.text('Code expires in 3:00'), findsWidgets);
        expectReachableWithoutScrolling(tester, _btn('Verify'));
      });

      testWidgets('verify email: an error sits in the pinned bar, also once '
          'the code has expired', (tester) async {
        final auth = _VerifyAuthHolder(error: 'That code is not right.');
        await pumpOnSmallPhone(tester, _verifyApp(auth), textScale: scale);
        await tester.pump();
        await _focusFirstField(tester, find.byType(OtpInput));
        await tester.pump(const Duration(seconds: 181));

        expectReachableWithoutScrolling(
            tester, find.text('That code is not right.'));
        expect(
            find.ancestor(
                of: find.text('That code is not right.'),
                matching: find.byType(McActionBar)),
            findsOneWidget);
        expectReachableWithoutScrolling(tester, _btn('Resend code'));
      });

      // --- A failed submit's message lands next to the pinned button -------
      // The error used to be the last thing in the scroll body, so after
      // tapping the pinned button it appeared below the visible area.
      final failedSubmits = <String, ({
        Widget screen,
        String button,
        String message,
      })>{
        'vehicle form': (
          screen: const VehicleFormScreen(),
          button: 'Save vehicle',
          message: 'Please fill in every field.',
        ),
        'sign up (email)': (
          screen: const EmailSignupScreen(initialMethod: SignupMethod.email),
          button: 'Create account',
          message: 'Please fill in every field.',
        ),
        'sign up (phone)': (
          screen: const EmailSignupScreen(),
          button: 'Continue',
          message: 'Please enter a valid phone number.',
        ),
        'verify (email)': (
          screen: const EmailLoginScreen(),
          button: 'Sign in',
          message: 'Please enter your email and password.',
        ),
        'verify (phone)': (
          screen: const VerifyScreen(),
          button: 'Send code',
          message: 'Please enter a valid phone number.',
        ),
      };
      for (final e in failedSubmits.entries) {
        for (final keyboard in const [false, true]) {
          testWidgets('${e.key}: the error is visible after a failed submit '
              '(keyboard ${keyboard ? 'open' : 'closed'})', (tester) async {
            await pumpOnSmallPhone(tester, _app(e.value.screen),
                textScale: scale, keyboardOpen: keyboard);
            await tester.pump(const Duration(milliseconds: 300));

            await tester.tap(_btn(e.value.button));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            expectReachableWithoutScrolling(tester, find.text(e.value.message));
          });
        }
      }

      // --- Vehicle tier ----------------------------------------------------
      testWidgets('vehicle tier: with the appeal form up, "Submit Appeal" is '
          'pinned and reachable', (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(const VehicleTierScreen(), overrides: [
            vehicleServiceProvider
                .overrideWithValue(_FakeVehicles(vehicle: _vehicle)),
          ]),
          textScale: scale,
        );
        await _load(tester);

        expect(find.text('REQUEST TIER CHANGE'), findsOneWidget);
        expectReachableWithoutScrolling(
            tester, _btn('Submit Appeal to Admin'));

        await _focusFirstField(tester);
        expectReachableWithoutScrolling(
            tester, _btn('Submit Appeal to Admin'));
      });

      testWidgets('vehicle tier: the reason field, focused with the keyboard '
          'up, scrolls wholly above the pinned bar', (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(const VehicleTierScreen(), overrides: [
            vehicleServiceProvider
                .overrideWithValue(_FakeVehicles(vehicle: _vehicle)),
          ]),
          textScale: scale,
        );
        await _load(tester);

        // Focus it as a driver would, then let the keyboard come up and the
        // field's own scroll-into-view run (no test-side ensureVisible).
        final field = find.byType(TextField).first;
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pump();
        await showKeyboard(tester);
        await tester.pump(const Duration(milliseconds: 600));

        final bar = tester.getRect(find.byType(McActionBar));
        final box = tester.getRect(field);
        expect(box.bottom, lessThanOrEqualTo(bar.top + 0.01),
            reason: 'the reason field $box is partly behind the pinned bar '
                '$bar');
      });

      testWidgets('vehicle tier: with an appeal pending there is no pinned bar '
          'and the content scrolls clear of the nav bar', (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(const VehicleTierScreen(), overrides: [
            vehicleServiceProvider.overrideWithValue(_FakeVehicles(
              vehicle: _vehicle,
              appeals: [
                _appeal('Pending'),
                _appeal('Rejected', reason: 'LAST-PAST-APPEAL'),
              ],
            )),
          ]),
          textScale: scale,
        );
        await _load(tester);

        expect(find.byType(McActionBar), findsNothing);
        expect(find.text('REQUEST TIER CHANGE'), findsNothing);

        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -3000));
        await tester.pump(const Duration(milliseconds: 500));
        final last = find.text('APPEAL HISTORY');
        expect(last, findsOneWidget);
        // The very end of the content is the last card; it must end above the
        // nav bar, so measure the scroll view's content, not just a label.
        final card = find.ancestor(
            of: find.textContaining('Rejected').last,
            matching: find.byType(McCard));
        expect(card, findsWidgets);
        expect(tester.getRect(card.last).bottom,
            lessThanOrEqualTo(visibleBottom(tester) + 0.01),
            reason: 'the last appeal card still sits under the nav bar after '
                'scrolling to the end');
      });
    });
  }

  // --- Behaviour is unchanged ----------------------------------------------
  group('DriverProfileForm: moving the button changed no behaviour', () {
    testWidgets('an empty name still shows the validation error, saves nothing',
        (tester) async {
      final auth = _FakeAuth(_profile(first: null, last: null));
      await pumpOnSmallPhone(
        tester,
        _app(const RegistrationScreen(),
            auth: auth),
      );
      await _load(tester);

      await tester.ensureVisible(_btn('Continue'));
      await tester.tap(_btn('Continue'));
      await tester.pump();

      expect(find.text('Please enter your full legal name.'), findsOneWidget);
      expect(auth.updates, isEmpty);
    });

    testWidgets('a missing National Insurance number is still caught',
        (tester) async {
      final auth = _FakeAuth(_profile(nationalId: null));
      await pumpOnSmallPhone(
        tester,
        _app(const RegistrationScreen(),
            auth: auth),
      );
      await _load(tester);

      await tester.ensureVisible(_btn('Continue'));
      await tester.tap(_btn('Continue'));
      await tester.pump();

      expect(find.text('Please enter your National Insurance number.'),
          findsOneWidget);
      expect(auth.updates, isEmpty);
    });

    testWidgets('a valid form saves once and then runs onSubmitted (pops)',
        (tester) async {
      final auth = _FakeAuth(_profile());
      await pumpOnSmallPhone(
        tester,
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: McButton('Open', full: false, onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const EditProfileScreen()));
                }),
              ),
            ),
          ),
          auth: auth,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 400));
      await _load(tester);
      expect(find.byType(EditProfileScreen), findsOneWidget);

      await tester.ensureVisible(_btn('Save changes'));
      await tester.tap(_btn('Save changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(auth.updates, ['James|Kowalski|QQ123456C']);
      expect(find.byType(EditProfileScreen), findsNothing);
    });

    testWidgets('the button is disabled until the saved profile has loaded',
        (tester) async {
      final gate = Completer<void>();
      final auth = _FakeAuth(_profile(), hold: gate.future);
      await pumpOnSmallPhone(tester, _app(const EditProfileScreen(), auth: auth));
      await _load(tester);
      // The profile is still on its way: saving now would send blanks.
      expect(tester.widget<McButton>(_btn('Save changes')).onTap, isNull);

      gate.complete();
      await _load(tester);
      expect(tester.widget<McButton>(_btn('Save changes')).onTap, isNotNull);
    });
  });

  // --- Scrolling screens: the end of the content clears the bottom --------
  // Profile / Settings keep "Log out" and their other buttons in the scroll;
  // they only need the scroll to end above the (inset-aware) tab bar.
  for (final scale in const [1.0, 1.3]) {
    group('scroll end, text x$scale', () {
      Future<void> expectScrollEndsAboveTabBar(WidgetTester tester) async {
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -6000));
        await tester.pump(const Duration(milliseconds: 600));
        final tabBar = tester.getRect(find.byType(DriverTabBar));
        final scroll = tester.getRect(find.byType(SingleChildScrollView).first);
        expect(scroll.bottom, lessThanOrEqualTo(tabBar.top + 0.01),
            reason: 'the scrolling content runs under the tab bar');
        // And the tab bar itself is clear of the nav bar.
        expect(tabBar.top + 66, lessThanOrEqualTo(visibleBottom(tester) + 0.01));
      }

      testWidgets('profile: the scroll ends above the tab bar', (tester) async {
        await pumpOnSmallPhone(
          tester,
          _app(const ProfileVehicleScreen(), overrides: [
            vehicleServiceProvider
                .overrideWithValue(_FakeVehicles(vehicle: _vehicle)),
            tripServiceProvider.overrideWithValue(_QuietTrips()),
          ]),
          textScale: scale,
        );
        await _load(tester);
        await expectScrollEndsAboveTabBar(tester);
      });

      testWidgets('settings: the scroll ends above the tab bar', (tester) async {
        await pumpOnSmallPhone(
            tester, _app(const DriverSettingsScreen()),
            textScale: scale);
        await _load(tester);
        await expectScrollEndsAboveTabBar(tester);
      });
    });
  }

  // --- Set route: the last suggestion row clears the nav bar ---------------
  testWidgets('set route: the last recent destination scrolls clear of the '
      'nav bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    final history = SearchHistoryService(prefs!);
    await tester.runAsync(() async {
      for (var i = 5; i >= 1; i--) {
        await history.add(
            null,
            Place(
                label: 'Destination $i',
                address: '$i Long Street Name, Some Borough, London AB$i 1CD',
                lat: 51.5 + i * 0.01,
                lng: -0.1));
      }
    });
    installFakeMapAndLocation();
    await pumpOnSmallPhone(
      tester,
      _app(const SetRouteScreen(), overrides: [
        searchHistoryServiceProvider.overrideWithValue(history),
      ]),
      textScale: 1.3,
    );
    await _load(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 600));
    final lastRow = find
        .ancestor(
            of: find.text('Destination 5'), matching: find.byType(Container))
        .first;
    expect(tester.getRect(lastRow).bottom,
        lessThanOrEqualTo(visibleBottom(tester) + 0.01),
        reason: 'the last recent destination still sits under the nav bar '
            'after scrolling to the end');
  });

  // A long API error (the offline message carries a "Ref:" diagnosis line) must
  // not push the pinned Save button off a keyboard-covered small screen - and
  // must stay readable, by scrolling inside its own capped area.
  for (final scale in const [1.3, 2.0]) {
    testWidgets('edit profile: a long save error scrolls in its own area and '
        'the button stays reachable (keyboard open, text ×$scale)',
        (tester) async {
      const long = "Can't reach Mapcars. Please check your internet connection "
          'and try again.\nRef: connection-error · DNS lookup failed for '
          'gce-test.mapcars.uk · attempt 3 of 3 · android 15 · app 1.0.0+6 · '
          'trace 7f3a9c21-4be0-4d52-9a67-1c2e8f0b5d44';
      final auth = _FakeAuth(_profile(), failWith: ApiException(message: long));
      await pumpOnSmallPhone(tester, _app(const EditProfileScreen(), auth: auth),
          textScale: scale);
      await _load(tester);

      await tester.ensureVisible(_btn('Save changes'));
      await tester.tap(_btn('Save changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _focusFirstField(tester);

      expect(find.textContaining('trace 7f3a9c21'), findsOneWidget);
      expectReachableWithoutScrolling(tester, _btn('Save changes'));
    });
  }
}
