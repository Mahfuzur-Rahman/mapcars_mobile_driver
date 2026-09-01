import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/brand.dart';

/// Footprint of the drawn car, in canvas units.
const carIconWidth = 64.0;
const carIconHeight = 128.0;

/// Draws a top-down sedan map marker (nose pointing north) for the driver's own
/// car on the navigation map.
///
/// The marker rotates to the driver's heading, so the view has to stay top-down
/// — a 3/4 perspective car looks wrong the moment it turns. All the depth
/// therefore comes from the lighting model in [_paintCar], not from viewpoint.
///
/// Pearl by default: this map's route polyline is green on the pickup leg and
/// blue on the trip leg, and pearl is the body colour that stays legible over
/// both — as well as on the night map style, where a dark car disappears.
///
/// Mirrors the customer app's `car_icon.dart` — the two apps deliberately
/// duplicate their core folders (see CLAUDE.md: no shared package), so keep the
/// two in sync if either is restyled. The customer copy additionally carries a
/// `drawGlowingCarIcon` halo variant, which has no caller here.
Future<BitmapDescriptor> drawCarIcon([Color body = Brand.carPearl]) async {
  const w = 64, h = 128;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  _paintCar(canvas, body);

  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    imagePixelRatio: 3.0,
  );
}

/// Paints the sedan at the canvas origin, occupying
/// [carIconWidth] × [carIconHeight].
///
/// Six things do the three-dimensional work, in the order they are drawn:
/// a soft **cast shadow** offset down-right so the car sits above the road; a
/// tight **contact shadow** that glues it back down; a body ramp whose far edge
/// gets *lighter* again (**bounce light**) the way a lit cylinder does and a
/// flat ramp does not; a narrow **specular band** on the lit shoulder; a
/// **dome falloff** darkening nose and tail so the roofline stands proud; and a
/// **rim light** plus **dark outline**, which are what keep a pale body legible
/// against a pale road.
void _paintCar(Canvas canvas, Color body) {
  Color shade(Color c, double amount) =>
      Color.lerp(c, amount >= 0 ? Colors.white : Colors.black, amount.abs())!;

  const shadowInk = Color(0xFF080E16);

  // Body — smooth sedan outline (narrow nose, wide flanks, rounded tail).
  // Built first because both shadows and the clips below are derived from it.
  final bodyPath = Path()
    ..moveTo(32, 4)
    ..cubicTo(45, 4, 51, 14, 52, 30)
    ..cubicTo(53.5, 48, 53.5, 78, 52, 98)
    ..cubicTo(51, 116, 44, 124, 32, 124)
    ..cubicTo(20, 124, 13, 116, 12, 98)
    ..cubicTo(10.5, 78, 10.5, 48, 12, 30)
    ..cubicTo(13, 14, 19, 4, 32, 4)
    ..close();

  // Soft cast shadow, offset down-right: the car reads as standing above the
  // road rather than printed onto it.
  canvas.drawOval(
    const Rect.fromLTWH(14.5, 15, 40, 112),
    Paint()
      ..color = shadowInk.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );

  // Tight contact shadow hugging the sills. Without this the car floats; the
  // soft shadow alone cannot both spread and stay anchored.
  canvas.drawOval(
    const Rect.fromLTWH(14, 13.5, 37.2, 110),
    Paint()
      ..color = shadowInk.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
  );

  // Body. The last stop lifting back toward light is the bounce light — it is
  // the single change that makes the flank read as curved metal.
  canvas.drawPath(
    bodyPath,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        const Offset(11, 0),
        const Offset(53, 0),
        [
          shade(body, 0.26),
          shade(body, 0.52), // specular band, kept narrow so it reads as gloss
          shade(body, 0.16),
          body,
          shade(body, -0.34),
          shade(body, -0.44),
          shade(body, -0.16), // bounce light off the far edge
        ],
        const [0.0, 0.13, 0.30, 0.52, 0.78, 0.92, 1.0],
      ),
  );

  canvas.save();
  canvas.clipPath(bodyPath);

  // Dome falloff: nose and tail sit lower than the roofline.
  canvas.drawRect(
    const Rect.fromLTWH(8, 0, 48, 128),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 4),
        const Offset(0, 124),
        [
          Colors.black.withValues(alpha: 0.34),
          Colors.black.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.05),
          Colors.black.withValues(alpha: 0.10),
          Colors.black.withValues(alpha: 0.32),
        ],
        const [0.0, 0.16, 0.42, 0.62, 0.86, 1.0],
      ),
  );

  // Long gloss streak down the lit flank.
  canvas.drawOval(
    const Rect.fromLTWH(16.1, 20, 6.8, 88),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
  );

  canvas.restore();

  // Side mirrors — lit on the near side, shadowed on the far side, so they
  // agree with the body's light direction instead of reading as flat tabs.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.5, 40, 9.5, 6.5), const Radius.circular(3.2)),
    Paint()
      ..isAntiAlias = true
      ..color = shade(body, 0.10),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(50, 40, 9.5, 6.5), const Radius.circular(3.2)),
    Paint()
      ..isAntiAlias = true
      ..color = shade(body, -0.34),
  );

  // Glass — graded rather than a flat fill, so the tint has a top edge.
  Paint glass(double y0, double y1) => Paint()
    ..isAntiAlias = true
    ..shader = ui.Gradient.linear(
      Offset(0, y0),
      Offset(0, y1),
      const [Color(0xFF38465A), Color(0xFF242E3C), Color(0xFF1A222C)],
      const [0.0, 0.55, 1.0],
    );

  final windshield = Path()
    ..moveTo(15, 38)
    ..quadraticBezierTo(32, 33, 49, 38)
    ..lineTo(46, 52)
    ..quadraticBezierTo(32, 47, 18, 52)
    ..close();
  canvas.drawPath(windshield, glass(33, 52));
  final rearWindow = Path()
    ..moveTo(17, 96)
    ..quadraticBezierTo(32, 102, 47, 96)
    ..lineTo(45, 108)
    ..quadraticBezierTo(32, 113, 19, 108)
    ..close();
  canvas.drawPath(rearWindow, glass(96, 113));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 56, 5, 36), const Radius.circular(2.5)),
    glass(56, 92),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 56, 5, 36), const Radius.circular(2.5)),
    glass(56, 92),
  );

  // Sky reflection across the top of the windscreen.
  final sheen = Path()
    ..moveTo(17, 39)
    ..quadraticBezierTo(30, 35, 41, 38)
    ..lineTo(39, 43)
    ..quadraticBezierTo(29, 40, 19, 44)
    ..close();
  canvas.drawPath(
    sheen,
    Paint()
      ..color = const Color(0xFFD6E8FF).withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
  );

  // Roof panel, lit across its width like the body beneath it.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(21, 55, 22, 38), const Radius.circular(9)),
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        const Offset(21, 0),
        const Offset(43, 0),
        [shade(body, 0.30), shade(body, 0.12), shade(body, -0.16)],
        const [0.0, 0.45, 1.0],
      ),
  );

  // Headlights + tail lights, each over a soft bloom so they read as emitting
  // rather than as painted-on rectangles.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(19, 7, 11, 6), const Radius.circular(3)),
    Paint()
      ..color = const Color(0xFFFFF7DE).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 7, 11, 6), const Radius.circular(3)),
    Paint()
      ..color = const Color(0xFFFFF7DE).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
  );
  final headlight = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFFFAFCFF).withValues(alpha: 0.96);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 8, 9, 4), const Radius.circular(2)),
    headlight,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(35, 8, 9, 4), const Radius.circular(2)),
    headlight,
  );

  final tailGlow = Paint()
    ..color = const Color(0xFFD63A2C).withValues(alpha: 0.5)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(21, 116, 10, 5), const Radius.circular(2.5)),
    tailGlow,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(33, 116, 10, 5), const Radius.circular(2.5)),
    tailGlow,
  );
  final taillight = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFFD63A2C).withValues(alpha: 0.95);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 117, 8, 3.5), const Radius.circular(2)),
    taillight,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 117, 8, 3.5), const Radius.circular(2)),
    taillight,
  );

  // Rim light along the lit flank — at true map size this is often the only
  // highlight that survives, so it is what still says "metal" when zoomed out.
  canvas.save();
  canvas.clipPath(bodyPath);
  canvas.drawPath(
    Path()
      ..moveTo(12, 30)
      ..cubicTo(10.5, 48, 10.5, 78, 12, 98),
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.55),
  );
  canvas.restore();

  // Outline. Non-negotiable for a pale body: without it a pearl car dissolves
  // into a white road on the standard map style.
  canvas.drawPath(
    bodyPath,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF0A1018).withValues(alpha: 0.42),
  );
}
