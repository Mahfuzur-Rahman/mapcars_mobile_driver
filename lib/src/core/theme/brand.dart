import 'package:flutter/material.dart';

/// MAP CARS brand tokens — mirrors the design system in `lib.jsx`.
class Brand {
  static const blue = Color(0xFF16A0D9);
  static const blueDeep = Color(0xFF1183C2);
  static const green = Color(0xFF4FBF3B);
  static const lime = Color(0xFF9ED11F);
  static const ink = Color(0xFF283443);
  static const sub = Color(0xFF7C8794);
  static const faint = Color(0xFFAEB7C0);
  static const line = Color(0xFFDBE0E6);
  static const fill = Color(0xFFEDF0F3);
  static const fillDeep = Color(0xFFE1E6EB);
  static const paper = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF4F6F8);
  static const star = Color(0xFFF5A623);

  // Gradients used by buttons / hero cards.
  static const grad = LinearGradient(colors: [blue, green]);
  static const gradGreen = LinearGradient(colors: [green, lime]);
  static const gradBlueGreen = LinearGradient(
    colors: [blue, Color(0xFF2BB6C7), green],
    stops: [0.0, 0.6, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardShadow = [
    BoxShadow(color: Color(0x0A283443), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const floatShadow = [
    BoxShadow(color: Color(0x29283443), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const sheetShadow = [
    BoxShadow(color: Color(0x24283443), blurRadius: 30, offset: Offset(0, -8)),
  ];
}
