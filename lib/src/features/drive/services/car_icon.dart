import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws a top-down sedan map marker (nose pointing north) for the driver's own
/// car on the navigation map. Mirrors the customer app's `car_icon.dart` — the
/// two apps deliberately duplicate their core folders (see CLAUDE.md: no shared
/// package), so keep the two in sync if either is restyled.
Future<BitmapDescriptor> drawCarIcon([Color body = const Color(0xFF15181C)]) async {
  const w = 64, h = 128;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  Color shade(Color c, double amount) =>
      Color.lerp(c, amount >= 0 ? Colors.white : Colors.black, amount.abs())!;

  // Soft ground shadow.
  canvas.drawOval(
    const Rect.fromLTWH(12, 12, 40, 112),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );

  // Body — smooth sedan outline (narrow nose, wide flanks, rounded tail).
  final bodyPath = Path()
    ..moveTo(32, 4)
    ..cubicTo(45, 4, 51, 14, 52, 30)
    ..cubicTo(53.5, 48, 53.5, 78, 52, 98)
    ..cubicTo(51, 116, 44, 124, 32, 124)
    ..cubicTo(20, 124, 13, 116, 12, 98)
    ..cubicTo(10.5, 78, 10.5, 48, 12, 30)
    ..cubicTo(13, 14, 19, 4, 32, 4)
    ..close();
  canvas.drawPath(
    bodyPath,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        const Offset(12, 0),
        const Offset(52, 0),
        [shade(body, 0.22), body, shade(body, -0.35)],
        [0.0, 0.45, 1.0],
      ),
  );

  // Side mirrors.
  final trim = Paint()
    ..isAntiAlias = true
    ..color = shade(body, -0.25);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 40, 9, 6), const Radius.circular(3)),
    trim,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(50, 40, 9, 6), const Radius.circular(3)),
    trim,
  );

  // Glass — dark blue-gray like tinted windows.
  final glass = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFF2B333E);
  final windshield = Path()
    ..moveTo(15, 38)
    ..quadraticBezierTo(32, 33, 49, 38)
    ..lineTo(46, 52)
    ..quadraticBezierTo(32, 47, 18, 52)
    ..close();
  canvas.drawPath(windshield, glass);
  final rearWindow = Path()
    ..moveTo(17, 96)
    ..quadraticBezierTo(32, 102, 47, 96)
    ..lineTo(45, 108)
    ..quadraticBezierTo(32, 113, 19, 108)
    ..close();
  canvas.drawPath(rearWindow, glass);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 56, 5, 36), const Radius.circular(2.5)),
    glass,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 56, 5, 36), const Radius.circular(2.5)),
    glass,
  );

  // Roof panel, a touch lighter than the body.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(21, 55, 22, 38), const Radius.circular(9)),
    Paint()
      ..isAntiAlias = true
      ..color = shade(body, 0.10),
  );

  // Headlights + tail lights.
  final headlight = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFFE9EEF4).withValues(alpha: 0.9);
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
  final taillight = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFFC0392B).withValues(alpha: 0.9);
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

  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    imagePixelRatio: 3.0,
  );
}
