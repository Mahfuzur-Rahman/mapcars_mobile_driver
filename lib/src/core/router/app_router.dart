import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/error_reporter.dart';
import '../widgets/screen_stepper.dart';
import '../../features/account/presentation/change_password_screen.dart';
import '../../features/account/presentation/earnings_screen.dart';
import '../../features/account/presentation/edit_profile_screen.dart';
import '../../features/account/presentation/history_screen.dart';
import '../../features/account/presentation/payouts_screen.dart';
import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/settings_screen.dart';
import '../../features/account/presentation/vehicle_form_screen.dart';
import '../../features/account/services/vehicle_service.dart';
import '../../features/dev/presentation/screen_index.dart';
import '../../features/drive/presentation/arrived_screen.dart';
import '../../features/drive/presentation/chat_screen.dart';
import '../../features/drive/presentation/driving_screen.dart';
import '../../features/drive/presentation/home_screen.dart';
import '../../features/drive/presentation/nav_pickup_screen.dart';
import '../../features/drive/presentation/request_preview_screen.dart';
import '../../features/drive/presentation/trip_complete_screen.dart';
import '../../features/drive/services/trip_service.dart';
import '../../features/onboarding/presentation/documents_screen.dart';
import '../../features/onboarding/presentation/email_login_screen.dart';
import '../../features/onboarding/presentation/email_signup_screen.dart';
import '../../features/onboarding/presentation/email_verify_screen.dart';
import '../../features/onboarding/presentation/intro_screen.dart';
import '../../features/onboarding/presentation/registration_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/under_review_screen.dart';
import '../../features/onboarding/presentation/verify_screen.dart';
import '../../features/navigate/models/place.dart';
import '../../features/navigate/presentation/route_preview_screen.dart';
import '../../features/navigate/presentation/set_route_screen.dart';

/// Ordered walk-through used by the floating hamburger menu drawer.
///
/// Entries carrying an `icon` are the real user-facing menu: they are the only
/// ones the drawer shows outside dev builds. Everything else is a prototype
/// step — a driver must not be able to jump into `/driving` or
/// `/trip-complete` from a menu with no trip attached.
const List<StepRoute> kDriverFlow = [
  StepRoute('/', 'Splash', category: 'Onboarding'),
  StepRoute('/intro', 'Intro', category: 'Onboarding'),
  StepRoute('/email-login', 'Email log-in', category: 'Onboarding'),
  StepRoute('/verify', 'Verify', category: 'Onboarding'),
  StepRoute('/email-signup', 'Sign up', category: 'Onboarding'),
  StepRoute('/verify-email', 'Email verify', category: 'Onboarding'),
  StepRoute('/registration', 'Registration', category: 'Onboarding'),
  StepRoute('/documents', 'Documents', category: 'Onboarding'),
  StepRoute('/under-review', 'Under review', category: 'Onboarding'),
  StepRoute('/home', 'Home', category: 'Driving Flow', icon: 'home'),
  StepRoute('/request', 'Request', category: 'Driving Flow'),
  StepRoute('/nav-pickup', 'Navigate', category: 'Driving Flow'),
  StepRoute('/arrived', 'Arrived', category: 'Driving Flow'),
  StepRoute('/chat', 'Chat', category: 'Driving Flow'),
  StepRoute('/driving', 'Driving', category: 'Driving Flow'),
  StepRoute('/trip-complete', 'Trip complete', category: 'Driving Flow'),
  StepRoute('/earnings', 'Earnings', category: 'Account', icon: 'chart'),
  StepRoute('/payouts', 'Payouts', category: 'Account', icon: 'bank'),
  StepRoute('/history', 'Trip history', category: 'Account', icon: 'clock'),
  StepRoute('/profile', 'Profile', category: 'Account', icon: 'user'),
  StepRoute('/profile/edit', 'Edit profile', category: 'Account'),
  StepRoute('/profile/vehicle', 'Vehicle', category: 'Account'),
  StepRoute('/settings', 'Settings', category: 'Account', icon: 'cog'),
  StepRoute('/settings/change-password', 'Change password', category: 'Account'),
  StepRoute('/screens', 'All Screens Index', category: 'Dev Tools'),
];

GoRoute _r(String path, Widget Function() b) =>
    GoRoute(path: path, builder: (c, s) => b());

/// Routes reachable without a session: the onboarding/verification funnel and
/// the dev-only screen index. The whole onboarding flow stays public because the
/// driver is mid-signup (registration → documents → approval) before they ever
/// reach the earning screens.
const _publicRoutes = {
  '/',
  '/intro',
  '/email-login',
  '/verify',
  '/email-signup',
  '/verify-email',
  '/registration',
  '/documents',
  '/under-review',
  '/screens',
};

/// Bridges [authTokenProvider] changes to go_router so guards re-evaluate the
/// moment the driver signs in or the session is torn down (e.g. on a 401).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen<String?>(authTokenProvider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription<String?> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authTokenProvider) != null;
      final path = state.uri.path;

      // Remember where we are so a crash report names the screen it happened on.
      ErrorReporter.currentRoute = path;

      // Auth gating applies in every build. It used to be skipped in local dev
      // for the prototype walk-through, which meant /home (and every other
      // signed-in screen) was reachable without a session — including straight
      // from the dev screen index.
      if (!loggedIn && !_publicRoutes.contains(path)) return '/intro';

      // The screen index is a prototype tool that links straight into signed-in
      // screens — it only exists in local dev builds.
      if (path == '/screens' && !AppConfig.isDev) return loggedIn ? '/home' : '/intro';
      const authFunnel = {'/email-login', '/verify', '/email-signup', '/verify-email'};
      if (loggedIn && authFunnel.contains(path)) return '/home';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => ScreenStepper(
            routes: kDriverFlow, current: state.uri.path, child: child),
        routes: [
          // Onboarding
          _r('/', () => const SplashScreen()),
          _r('/intro', () => const IntroScreen()),
          _r('/email-login', () => const EmailLoginScreen()),
          _r('/verify', () => const VerifyScreen()),
          _r('/email-signup', () => const EmailSignupScreen()),
          _r('/verify-email', () => const EmailVerifyScreen()),
          _r('/registration', () => const RegistrationScreen()),
          _r('/documents', () => const DocumentsScreen()),
          _r('/under-review', () => const UnderReviewScreen()),
          // Driving flow
          _r('/home', () => const DriverHomeScreen()),
          // Address search + directions
          _r('/set-route', () => const SetRouteScreen()),
          GoRoute(
            path: '/route-preview',
            builder: (c, s) {
              final dest = s.extra;
              if (dest is! Place) return const SetRouteScreen();
              return RoutePreviewScreen(destination: dest);
            },
          ),
          _r('/request', () => const RequestPreviewScreen()),
          GoRoute(
            path: '/nav-pickup',
            builder: (c, s) => NavPickupScreen(
              trip: s.extra is Trip ? s.extra as Trip : null,
            ),
          ),
          GoRoute(
            path: '/arrived',
            builder: (c, s) => ArrivedScreen(
              trip: s.extra is Trip ? s.extra as Trip : null,
            ),
          ),
          GoRoute(
            path: '/chat',
            builder: (c, s) => ChatScreen(
              trip: s.extra is Trip ? s.extra as Trip : null,
            ),
          ),
          GoRoute(
            path: '/driving',
            builder: (c, s) => DrivingScreen(
              trip: s.extra is Trip ? s.extra as Trip : null,
            ),
          ),
          GoRoute(
            path: '/trip-complete',
            builder: (c, s) => TripCompleteScreen(
              trip: s.extra is Trip ? s.extra as Trip : null,
            ),
          ),
          // Account
          _r('/earnings', () => const EarningsScreen()),
          _r('/payouts', () => const PayoutsScreen()),
          _r('/history', () => const DriverHistoryScreen()),
          _r('/profile', () => const ProfileVehicleScreen()),
          _r('/profile/edit', () => const EditProfileScreen()),
          GoRoute(
            path: '/profile/vehicle',
            builder: (c, s) => VehicleFormScreen(
              vehicle: s.extra is Vehicle ? s.extra as Vehicle : null,
            ),
          ),
          _r('/settings', () => const DriverSettingsScreen()),
          _r('/settings/change-password', () => const ChangePasswordScreen()),
          // Prototype screen index
          _r('/screens', () => const ScreenIndexScreen()),
        ],
      ),
    ],
  );
});
