import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class ArrivedScreen extends StatelessWidget {
  const ArrivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: false,
              markers: [
                MapMarker(0.50, 0.40, MapPin(dest: true, label: 'Pickup')),
              ],
            ),
          ),
          Positioned(
            top: 56,
            left: 16,
            child: McCircleButton('back', onTap: () => context.pop()),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 342,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const McAvatar(size: 52, color: Brand.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Sarah M.',
                                style: tw(FontWeight.w900, 17, Brand.ink)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Ico('starF', size: 14, color: Brand.star),
                                const SizedBox(width: 4),
                                Text('4.8',
                                    style: tw(FontWeight.w800, 13, Brand.sub)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const _SquareButton(icon: 'phone'),
                      const SizedBox(width: 8),
                      const _SquareButton(icon: 'msg'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  McCard(
                    padding: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Confirm rider's PIN",
                            style: tw(FontWeight.w700, 12.5, Brand.sub)),
                        const SizedBox(height: 10),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PinBox('4'),
                            SizedBox(width: 10),
                            _PinBox('8'),
                            SizedBox(width: 10),
                            _PinBox('2'),
                            SizedBox(width: 10),
                            _PinBox('1'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  McButton(
                    'Start trip',
                    icon: 'nav',
                    kind: BtnKind.green,
                    onTap: () => context.go('/driving'),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Brand.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Ico(icon, size: 20, color: Brand.ink)),
      );
}

class _PinBox extends StatelessWidget {
  const _PinBox(this.digit);
  final String digit;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 50,
        decoration: BoxDecoration(
          color: Brand.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(digit, style: tw(FontWeight.w900, 22, Brand.ink)),
        ),
      );
}
