import 'package:flutter/material.dart';

import 'brand.dart';

class AppTheme {
  // Nunito is bundled as a variable font asset (see pubspec) — no network needed.
  static const String fontFamily = 'Nunito';

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: Brand.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Brand.blue,
        primary: Brand.blue,
        surface: Brand.paper,
      ),
    ).copyWith(
      textTheme: ThemeData(useMaterial3: true).textTheme
          .apply(fontFamily: fontFamily, bodyColor: Brand.ink, displayColor: Brand.ink),
    );
  }

  // The apps are light-only for the prototype; dark mirrors light.
  static ThemeData get dark => light;
}
