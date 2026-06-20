import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _online = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: false,
              markers: [
                MapMarker(0.46, 0.42, CarMark(color: Brand.blue, icon: 'nav')),
                MapMarker(
                  0.70,
                  0.30,
                  _DemandBlob(size: 70, opacity: 0.25),
                ),
                MapMarker(
                  0.24,
                  0.56,
                  _DemandBlob(size: 54, opacity: 0.18),
                ),
              ],
            ),
          ),
          // Top: online status pill + avatar
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
                  decoration: const BoxDecoration(
                    color: Brand.paper,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                    boxShadow: Brand.floatShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _online ? 'Online' : 'Offline',
                        style: tw(FontWeight.w900, 14,
                            _online ? Brand.green : Brand.sub),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 54,
                        height: 32,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Switch(
                            value: _online,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Brand.green,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Brand.line,
                            onChanged: (v) => setState(() => _online = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                McCircleButton('user', onTap: () => context.go('/profile')),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/request'),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Brand.fill, width: 3),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Brand.green),
                              backgroundColor: Brand.fill,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const McTitle('Waiting for requests…', size: 18),
                              const SizedBox(height: 2),
                              Text(
                                "You're online near Bethnal Green",
                                style: tw(FontWeight.w600, 13, Brand.sub),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const McCard(
                    padding: 14,
                    child: Row(
                      children: [
                        _Stat('£62.40', 'Earnings'),
                        _Stat('5', 'Trips'),
                        _Stat('3h 12m', 'Online'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: McGhostButton(
                          'Earnings',
                          icon: 'chart',
                          onTap: () => context.go('/earnings'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: McGhostButton(
                          _online ? 'Go offline' : 'Go online',
                          onTap: () => setState(() => _online = !_online),
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

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: tw(FontWeight.w900, 18, Brand.ink)),
            const SizedBox(height: 2),
            Text(label, style: tw(FontWeight.w700, 11.5, Brand.sub)),
          ],
        ),
      );
}

class _DemandBlob extends StatelessWidget {
  const _DemandBlob({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF7961E).withValues(alpha: opacity),
        ),
      );
}
