import 'package:flutter/material.dart';

/// MAP CARS brand tokens — mirrors the design system in `lib.jsx`.
class Brand {
  static const blue = Color(0xFF0B7DC0);
  static const blueDeep = Color(0xFF085E94);
  static const green = Color(0xFF31A424);
  static const lime = Color(0xFF7FB512);
  static const ink = Color(0xFF16202E);
  static const sub = Color(0xFF566372);
  static const faint = Color(0xFF8B98A6);
  static const line = Color(0xFFC9D1DA);
  static const fill = Color(0xFFE5EAEF);
  static const fillDeep = Color(0xFFD5DCE4);
  static const paper = Color(0xFFFFFFFF);
  static const bg = Color(0xFFEBEFF3);
  static const star = Color(0xFFE99400);

  // Error alert tokens
  static const errorBg = Color(0xFFFDF2F2);
  static const errorBorder = Color(0xFFF8B4B4);
  static const errorText = Color(0xFF9B1C1C);

  // Gradients used by buttons / hero cards.
  static const grad = LinearGradient(colors: [blue, green]);
  static const gradGreen = LinearGradient(colors: [green, lime]);
  static const gradBlueGreen = LinearGradient(
    colors: [blue, Color(0xFF12939F), green],
    stops: [0.0, 0.6, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardShadow = [
    BoxShadow(color: Color(0x1416202E), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const floatShadow = [
    BoxShadow(color: Color(0x2E16202E), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const sheetShadow = [
    BoxShadow(color: Color(0x3316202E), blurRadius: 32, offset: Offset(0, -10)),
  ];
}
