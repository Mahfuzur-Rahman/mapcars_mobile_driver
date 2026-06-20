import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../widgets/screen_stepper.dart';
import '../../features/account/presentation/earnings_screen.dart';
import '../../features/account/presentation/history_screen.dart';
import '../../features/account/presentation/payouts_screen.dart';
import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/settings_screen.dart';
import '../../features/dev/presentation/screen_index.dart';
import '../../features/drive/presentation/arrived_screen.dart';
import '../../features/drive/presentation/driving_screen.dart';
import '../../features/drive/presentation/home_screen.dart';
import '../../features/drive/presentation/nav_pickup_screen.dart';
import '../../features/drive/presentation/request_screen.dart';
import '../../features/drive/presentation/trip_complete_screen.dart';
import '../../features/onboarding/presentation/documents_screen.dart';
import '../../features/onboarding/presentation/intro_screen.dart';
import '../../features/onboarding/presentation/registration_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/under_review_screen.dart';
import '../../features/onboarding/presentation/verify_screen.dart';

/// Ordered walk-through used by the floating Next/Prev stepper.
const List<StepRoute> kDriverFlow = [
  StepRoute('/', 'Splash'),
  StepRoute('/intro', 'Intro'),
  StepRoute('/verify', 'Verify'),
  StepRoute('/registration', 'Registration'),
  StepRoute('/documents', 'Documents'),
  StepRoute('/under-review', 'Under review'),
  StepRoute('/home', 'Home'),
  StepRoute('/request', 'Request'),
  StepRoute('/nav-pickup', 'Navigate'),
  StepRoute('/arrived', 'Arrived'),
  StepRoute('/driving', 'Driving'),
  StepRoute('/trip-complete', 'Trip complete'),
  StepRoute('/earnings', 'Earnings'),
  StepRoute('/payouts', 'Payouts'),
  StepRoute('/history', 'Trip history'),
  StepRoute('/profile', 'Profile'),
  StepRoute('/settings', 'Settings'),
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
  '/verify',
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
      // Keep the prototype walk-through fully open in local dev; enforce real
      // auth gating only in staging/prod builds.
      if (AppConfig.isDev) return null;

      final loggedIn = ref.read(authTokenProvider) != null;
      final path = state.uri.path;

      if (!loggedIn && !_publicRoutes.contains(path)) return '/intro';
      if (loggedIn && path == '/verify') return '/home';
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
          _r('/verify', () => const VerifyScreen()),
          _r('/registration', () => const RegistrationScreen()),
          _r('/documents', () => const DocumentsScreen()),
          _r('/under-review', () => const UnderReviewScreen()),
          // Driving flow
          _r('/home', () => const DriverHomeScreen()),
          _r('/request', () => const RequestScreen()),
          _r('/nav-pickup', () => const NavPickupScreen()),
          _r('/arrived', () => const ArrivedScreen()),
          _r('/driving', () => const DrivingScreen()),
          _r('/trip-complete', () => const TripCompleteScreen()),
          // Account
          _r('/earnings', () => const EarningsScreen()),
          _r('/payouts', () => const PayoutsScreen()),
          _r('/history', () => const DriverHistoryScreen()),
          _r('/profile', () => const ProfileVehicleScreen()),
          _r('/settings', () => const DriverSettingsScreen()),
          // Prototype screen index
          _r('/screens', () => const ScreenIndexScreen()),
        ],
      ),
    ],
  );
});
