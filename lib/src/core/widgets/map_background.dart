import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/mc_icons.dart';

/// A marker placed on the map by fractional position (0..1 of width/height).
class MapMarker {
  const MapMarker(this.fx, this.fy, this.child);
  final double fx;
  final double fy;
  final Widget child;
}

/// Stylised street map backdrop (approximates the `MapBg` SVG from the design).
/// Use as the bottom layer of a screen Stack; add sheets/top-bars above it.
class MapBackground extends StatelessWidget {
  const MapBackground({super.key, this.route = true, this.markers = const []});
  final bool route;
  final List<MapMarker> markers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPainter(route: route))),
            for (final m in markers)
              Positioned(
                left: m.fx * w,
                top: m.fy * h,
                child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: m.child),
              ),
          ],
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.route});
  final bool route;

  // Design space is 402 x 700; scale to the real canvas.
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 402.0;
    final sy = size.height / 700.0;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    // Land.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEAEDED));

    // Building footprints (deterministic LCG, like the JSX).
    final block = Paint()..color = const Color(0xFFE0E3E4);
    int seed = 11;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }
    for (int i = 0; i < 110; i++) {
      final x = rnd() * 402, y = rnd() * 700, bw = 9 + rnd() * 24, bh = 9 + rnd() * 24;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x * sx, y * sy, bw * sx, bh * sy), const Radius.circular(2)),
        block,
      );
    }

    // Park + water.
    final park = Paint()..color = const Color(0xFFC6E5B6);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(24 * sx, 150 * sy, 118 * sx, 74 * sy), const Radius.circular(13)), park);
    final water = Paint()..color = const Color(0xFFA9D4F0);
    final wp = Path()
      ..moveTo(-20 * sx, 545 * sy)
      ..quadraticBezierTo(70 * sx, 502 * sy, 132 * sx, 548 * sy)
      ..quadraticBezierTo(214 * sx, 606 * sy, 150 * sx, 720 * sy)
      ..lineTo(-20 * sx, 720 * sy)
      ..close();
    canvas.drawPath(wp, water);

    // Minor roads.
    final roadEdge = Paint()
      ..color = const Color(0xFFD2D7DA)
      ..strokeWidth = 8 * sx
      ..strokeCap = StrokeCap.round;
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.5 * sx
      ..strokeCap = StrokeCap.round;
    const List<double> minorV = [45, 95, 250, 320, 366];
    const List<double> minorH = [108, 172, 358, 430, 598, 652];
    for (final paint in [roadEdge, road]) {
      for (final x in minorV) {
        canvas.drawLine(p(x, -10), p(x + 12, 710), paint);
      }
      for (final y in minorH) {
        canvas.drawLine(p(-10, y), p(412, y - 12), paint);
      }
    }

    // Arterials.
    final arterials = [
      (Path()
        ..moveTo(150 * sx, -20 * sy)
        ..cubicTo(162 * sx, 140 * sy, 116 * sx, 320 * sy, 172 * sx, 470 * sy)
        ..cubicTo(198 * sx, 588 * sy, 182 * sx, 720 * sy, 196 * sx, 720 * sy)),
      (Path()
        ..moveTo(-20 * sx, 250 * sy)
        ..cubicTo(110 * sx, 236 * sy, 214 * sx, 302 * sy, 422 * sx, 266 * sy)),
    ];
    for (final a in arterials) {
      canvas.drawPath(a, Paint()..color = const Color(0xFFD2D7DA)..style = PaintingStyle.stroke..strokeWidth = 17 * sx..strokeCap = StrokeCap.round);
      canvas.drawPath(a, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 12 * sx..strokeCap = StrokeCap.round);
    }

    // Highway (yellow).
    final hw = Path()
      ..moveTo(-20 * sx, 560 * sy)
      ..cubicTo(110 * sx, 520 * sy, 232 * sx, 470 * sy, 422 * sx, 356 * sy);
    canvas.drawPath(hw, Paint()..color = const Color(0xFFECD589)..style = PaintingStyle.stroke..strokeWidth = 18 * sx..strokeCap = StrokeCap.round);
    canvas.drawPath(hw, Paint()..color = const Color(0xFFF8E6A6)..style = PaintingStyle.stroke..strokeWidth = 13 * sx..strokeCap = StrokeCap.round);

    // Route.
    if (route) {
      final r = Path()
        ..moveTo(100 * sx, 612 * sy)
        ..cubicTo(150 * sx, 524 * sy, 120 * sx, 432 * sy, 200 * sx, 382 * sy)
        ..cubicTo(280 * sx, 332 * sy, 250 * sx, 212 * sy, 300 * sx, 150 * sy);
      canvas.drawPath(r, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 11 * sx..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      canvas.drawPath(r, Paint()..color = const Color(0xFF1573C9)..style = PaintingStyle.stroke..strokeWidth = 6.5 * sx..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.route != route;
}

/// Pickup pin (green dot) or destination pin (blue teardrop).
class MapPin extends StatelessWidget {
  const MapPin({super.key, this.dest = true, this.label});
  final bool dest;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (!dest) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
        ]),
        child: Center(
          child: Container(width: 11, height: 11, decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle)),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.location_on, size: 40, color: Brand.blue),
      if (label != null)
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), boxShadow: Brand.floatShadow),
          child: Text(label!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.ink)),
        ),
    ]);
  }
}

/// Car marker (dark circle with an icon) used during tracking/navigation.
class CarMark extends StatelessWidget {
  const CarMark({super.key, this.color = Brand.ink, this.icon = 'car'});
  final Color color;
  final String icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 10, offset: Offset(0, 4)),
        ]),
        child: Center(child: Ico(icon, size: 20, color: Colors.white)),
      );
}
