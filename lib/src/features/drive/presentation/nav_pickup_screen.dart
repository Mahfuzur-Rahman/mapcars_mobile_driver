import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class NavPickupScreen extends StatelessWidget {
  const NavPickupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: true,
              markers: [
                MapMarker(0.30, 0.80, CarMark(color: Brand.blue, icon: 'nav')),
                MapMarker(0.72, 0.26, MapPin(dest: false)),
              ],
            ),
          ),
          const Positioned(
            top: 50,
            left: 14,
            right: 14,
            child: _TurnBanner(
              dist: '300 m',
              road: "Right onto King's Rd",
              kind: 'green',
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 236,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Brand.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Pickup · Sarah M.',
                            style: tw(FontWeight.w900, 15, Brand.ink)),
                      ),
                      Text('4 min', style: tw(FontWeight.w800, 14, Brand.green)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('40 Canary Wharf, London E14',
                      style: tw(FontWeight.w700, 13.5, Brand.sub)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const _SquareButton(icon: 'phone'),
                      const SizedBox(width: 10),
                      const _SquareButton(icon: 'msg'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: McButton(
                          'Navigate',
                          icon: 'nav',
                          onTap: () => context.go('/arrived'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon});
  final String icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Brand.fill,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(child: Ico(icon, size: 22, color: Brand.ink)),
      );
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner(
      {required this.dist, required this.road, this.kind = 'green'});
  final String dist;
  final String road;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final bg = kind == 'green' ? Brand.green : Brand.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D283443),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Ico('turn', size: 34, color: Colors.white),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dist,
                  style: tw(FontWeight.w900, 22, Colors.white).copyWith(
                      height: 1)),
              const SizedBox(height: 3),
              Text(road,
                  style: tw(FontWeight.w700, 13.5,
                      Colors.white.withValues(alpha: 0.9))),
            ],
          ),
        ],
      ),
    );
  }
}
