import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class RequestScreen extends StatelessWidget {
  const RequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: MapBackground(route: true)),
          Positioned.fill(
            child: Container(color: Brand.ink.withValues(alpha: 0.45)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
              decoration: const BoxDecoration(
                color: Brand.paper,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 40,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Brand.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('New request',
                              style: tw(FontWeight.w900, 15, Brand.green)),
                        ],
                      ),
                      // countdown ring
                      SizedBox(
                        width: 46,
                        height: 46,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const SizedBox(
                              width: 46,
                              height: 46,
                              child: CircularProgressIndicator(
                                value: 0.7,
                                strokeWidth: 5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Brand.green),
                                backgroundColor: Brand.fill,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text('9', style: tw(FontWeight.w900, 16, Brand.ink)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // rider row
                  Row(
                    children: [
                      const McAvatar(size: 48, color: Brand.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Sarah M.',
                                style: tw(FontWeight.w900, 16, Brand.ink)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Ico('starF', size: 14, color: Brand.star),
                                const SizedBox(width: 4),
                                Text('4.8 · Economy',
                                    style: tw(FontWeight.w800, 13, Brand.sub)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('£11.50',
                              style: tw(FontWeight.w900, 24, Brand.ink)),
                          Text('fare', style: tw(FontWeight.w700, 12, Brand.sub)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // info tiles
                  const Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                            icon: 'pin', value: '4 min', sub: '0.8 mi pickup'),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _InfoTile(
                            icon: 'nav', value: '18 min', sub: '4.3 mi trip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  McButton(
                    'Accept',
                    icon: 'check',
                    kind: BtnKind.green,
                    height: 58,
                    onTap: () => context.go('/nav-pickup'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Text('Decline',
                          style: tw(FontWeight.w800, 15, Brand.sub)),
                    ),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon, required this.value, required this.sub});
  final String icon;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Brand.fill,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Ico(icon, size: 20, color: Brand.sub),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: tw(FontWeight.w900, 14, Brand.ink)),
                Text(sub, style: tw(FontWeight.w600, 11.5, Brand.sub)),
              ],
            ),
          ],
        ),
      );
}
