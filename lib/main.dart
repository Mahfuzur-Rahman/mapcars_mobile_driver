import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

    // Platform-layer (Java/Kotlin) crashes and ANRs never reach Dart's error
    // hooks at all — that is the gap Crashlytics fills, and it captures them
    // with no Dart code involved. NDK/C++ crashes are deliberately NOT covered:
    // those need the separate firebase-crashlytics-ndk artifact, which is not
    // included, and the built bundle carries no libcrashlytics.so.
    //
    // Dart-side errors are forwarded through ErrorReporter's sink list rather
    // than by installing a second pair of handlers: Flutter
    // has only one FlutterError.onError and one PlatformDispatcher.onError, so
    // a second reporter would replace the first rather than stack with it.
    ErrorReporter.addSink(
      (error, stack) => FirebaseCrashlytics.instance
          .recordError(error, stack, fatal: false),
    );
  } catch (e) {
    debugPrint('[firebase] init skipped, crash + push reporting off: $e');
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
