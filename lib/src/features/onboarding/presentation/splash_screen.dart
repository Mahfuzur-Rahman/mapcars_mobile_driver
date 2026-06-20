import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// Restore any persisted session, then route the driver to the right place.
  Future<void> _boot() async {
    await ref.read(authNotifierProvider.notifier).restore();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final loggedIn = ref.read(authNotifierProvider).isAuthenticated;
    context.go(loggedIn ? '/home' : '/intro');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => context.go('/intro'),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFBBE6F6),
                Color(0xFFE7F6FB),
                Color(0xFFFFFFFF),
                Color(0xFFECF8E7),
                Color(0xFFC6ECBC),
              ],
              stops: [0.0, 0.26, 0.5, 0.74, 1.0],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/logo-full.png', height: 140),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Brand.ink,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Ico('wheel', size: 18, color: Brand.lime),
                            const SizedBox(width: 8),
                            Text('DRIVER', style: tw(FontWeight.w900, 14, Colors.white, 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 54,
                  left: 0,
                  right: 0,
                  child: Text(
                    'DRIVE & EARN',
                    textAlign: TextAlign.center,
                    style: tw(FontWeight.w800, 13, Brand.sub, 2),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TextButton(
                      onPressed: () => context.push('/screens'),
                      child: Text('Browse all screens', style: tw(FontWeight.w700, 13, Brand.sub)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
