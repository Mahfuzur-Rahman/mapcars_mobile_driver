import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide [SharedPreferences] handle for non-sensitive on-device state
/// (e.g. per-user recent searches). Real secrets stay in secure storage.
///
/// Overridden in `main()` with the resolved instance so every provider gets a
/// synchronous handle instead of awaiting `getInstance()` on each read.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);
