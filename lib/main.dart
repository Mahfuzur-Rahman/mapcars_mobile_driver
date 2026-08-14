import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/core/network/error_reporter.dart';
import 'src/core/notifications/push_service.dart';
import 'src/core/storage/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch every uncaught error from here on and ship it to the central error
  // log (admin portal → Error Logger). Installed first so failures during the
  // rest of start-up are reported too.
  ErrorReporter.install();

  // Load configuration (API base URL, Google Maps key) from the bundled .env asset.
  await dotenv.load(fileName: '.env');

  // Init Firebase for push (FCM). Guarded so the app still runs if the native
  // Firebase config (google-services.json) isn't present in a given build.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  } catch (e) {
    debugPrint('[push] Firebase init skipped: $e');
  }

  // Resolve on-device prefs once so providers can read them synchronously.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MapcarsDriverApp(),
    ),
  );
}
