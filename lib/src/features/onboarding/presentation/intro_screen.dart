import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            children: [
              _topRow(),
              const SizedBox(height: 18),
              Expanded(
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _slide(
                      art: _scheduleArt(),
                      title: 'Drive on your\nown schedule',
                      body:
                          "Go online whenever it suits you. Accept the trips you want and take a break any time — you're the boss.",
                    ),
                    _slide(
                      art: _busyZonesArt(),
                      title: 'Earn more in\nbusy zones',
                      body:
                          'See where demand is high and surge is live. More requests, better fares, and bonuses for busy hours.',
                    ),
                    _slide(
                      art: _payoutsArt(),
                      title: 'Get paid,\nevery week',
                      body:
                          'Track your earnings in real time and cash out instantly, or get automatic weekly payouts straight to your bank.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _dots(),
              const SizedBox(height: 20),
              if (_page < 2)
                McButton('Next', icon: 'chevR', kind: BtnKind.green, onTap: _next)
              else
                McButton('Start driving', icon: 'wheel', kind: BtnKind.grad, onTap: () => context.go('/verify')),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.go('/verify'),
                child: RichText(
                  text: TextSpan(
                    style: tw(FontWeight.w700, 14, Brand.sub),
                    children: [
                      const TextSpan(text: 'Already approved? '),
                      TextSpan(text: 'Log in', style: tw(FontWeight.w700, 14, Brand.blue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset('assets/images/logo-full.png', height: 26),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(99)),
              child: Text('DRIVER', style: tw(FontWeight.w900, 11, Colors.white, 1.5)),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => context.go('/verify'),
          child: Text('Skip', style: tw(FontWeight.w800, 14, Brand.sub)),
        ),
      ],
    );
  }

  Widget _slide({required Widget art, required String title, required String body}) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 268,
              decoration: BoxDecoration(border: Border.all(color: Brand.line), borderRadius: BorderRadius.circular(22)),
              child: ClipRRect(borderRadius: BorderRadius.circular(22), child: art),
            ),
          ),
          const SizedBox(height: 26),
          McTitle(title, size: 29),
          const SizedBox(height: 12),
          Text(body, style: tw(FontWeight.w600, 15, Brand.sub)),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? Brand.green : Brand.line,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }

  // Slide 0 — map with car + Online toggle pill.
  Widget _scheduleArt() {
    return Stack(
      children: [
        const Positioned.fill(child: MapBackground(route: false)),
        const Align(
          alignment: Alignment(-0.04, -0.08),
          child: CarMark(color: Brand.blue, icon: 'nav'),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              boxShadow: Brand.floatShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Online', style: tw(FontWeight.w900, 13, Brand.green)),
                const SizedBox(width: 9),
                Container(
                  width: 42,
                  height: 25,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: Brand.green, borderRadius: BorderRadius.circular(99)),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 19,
                      height: 19,
                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Slide 1 — gradient panel with bar chart + surge badge.
  Widget _busyZonesArt() {
    const bars = [0.45, 0.7, 0.5, 0.85, 1.0, 0.6];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF6FB), Color(0xFFECF8E7)],
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 36),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (i) {
                final tall = i == 4;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      height: 150 * bars[i],
                      decoration: BoxDecoration(
                        color: tall ? null : Colors.white,
                        gradient: tall ? Brand.gradGreen : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Brand.line),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Brand.green, borderRadius: BorderRadius.circular(99)),
              child: Text('1.8× surge', style: tw(FontWeight.w900, 13, Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 2 — earnings card with Cash out.
  Widget _payoutsArt() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF6FB), Color(0xFFECF8E7)],
        ),
      ),
      child: Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Brand.line),
            boxShadow: const [BoxShadow(color: Color(0x1F283443), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Ico('bank', size: 18, color: Brand.green),
                  const SizedBox(width: 8),
                  Text('Available to cash out', style: tw(FontWeight.w800, 12, Brand.sub)),
                ],
              ),
              const SizedBox(height: 6),
              Text('£342.60', style: tw(FontWeight.w900, 34, Brand.ink, -1)),
              const SizedBox(height: 12),
              Container(
                height: 44,
                decoration: BoxDecoration(gradient: Brand.gradGreen, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('Cash out', style: tw(FontWeight.w800, 14, Colors.white))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
