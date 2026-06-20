import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration (API base URL, Mapbox token) from the bundled .env asset.
  await dotenv.load(fileName: '.env');

  runApp(const ProviderScope(child: MapcarsDriverApp()));
}
