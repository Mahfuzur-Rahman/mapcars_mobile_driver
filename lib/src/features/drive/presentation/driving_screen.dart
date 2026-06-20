import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class DrivingScreen extends StatelessWidget {
  const DrivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: true,
              markers: [
                MapMarker(0.42, 0.60, CarMark(color: Brand.blue, icon: 'nav')),
                MapMarker(0.72, 0.26, MapPin(dest: true)),
              ],
            ),
          ),
          Positioned(
            top: 50,
            left: 14,
            right: 14,
            child: GestureDetector(
              onTap: () => context.go('/trip-complete'),
              child: const _TurnBanner(
                dist: '1.2 mi',
                road: 'Continue on A1203',
                kind: 'blue',
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () => context.go('/trip-complete'),
              child: McSheet(
                height: 208,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Brand.blue,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Tower Bridge, SE1',
                              style: tw(FontWeight.w900, 15, Brand.ink)),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            width: 80,
                            height: 6,
                            color: Brand.fill,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.58,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Brand.blue, Brand.green],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        _StatCard(value: '12 min', sub: 'arrival 4:38'),
                        SizedBox(width: 10),
                        _StatCard(value: '3.1 mi', sub: 'remaining'),
                        SizedBox(width: 10),
                        _StatCard(
                            value: '£11.50',
                            sub: 'fare',
                            valueColor: Brand.green),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.value, required this.sub, this.valueColor = Brand.ink});
  final String value;
  final String sub;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
        child: McCard(
          padding: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: tw(FontWeight.w900, 17, valueColor)),
              const SizedBox(height: 2),
              Text(sub, style: tw(FontWeight.w700, 11, Brand.sub)),
            ],
          ),
        ),
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
                  style:
                      tw(FontWeight.w900, 22, Colors.white).copyWith(height: 1)),
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
