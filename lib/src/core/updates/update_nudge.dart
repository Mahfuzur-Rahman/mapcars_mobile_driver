import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/api_client.dart';
import '../widgets/mc.dart';

/// Which app this is, as the API's `GET /api/v1/app-version` spells it.
const _appName = 'driver';
const _dismissedKey = 'update_dismissed_version';

/// A newer build than the one running, published from the admin portal
/// (Settings → App versions).
class AppUpdate {
  const AppUpdate({required this.latest, required this.storeUrl, this.message});
  final String latest;
  final String storeUrl;
  final String? message;
}

/// Dotted-number comparison: is [latest] newer than [current]? Anything that
/// doesn't parse counts as "not newer" — a bad value must never nag.
@visibleForTesting
bool isNewerVersion(String latest, String current) {
  List<int>? parse(String v) {
    // Drop a "+build" suffix; package_info_plus gives the name only, but be safe.
    final parts = v.split('+').first.trim().split('.');
    final nums = parts.map(int.tryParse).toList();
    return nums.any((n) => n == null) || nums.isEmpty ? null : nums.cast<int>();
  }

  final a = parse(latest);
  final b = parse(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// The update to offer, or null: none published, already up to date, already
/// dismissed for this version, or anything at all went wrong. Soft-only by
/// design — a failure here must never get between a user and the app.
final appUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get<dynamic>(
      '/api/v1/app-version',
      queryParameters: {
        'app': _appName,
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
    );
    final data = res.data;
    if (data is! Map) return null;
    final latest = (data['latest'] as String? ?? '').trim();
    final url = (data['storeUrl'] as String? ?? '').trim();
    if (latest.isEmpty || url.isEmpty) return null;

    final current = (await PackageInfo.fromPlatform()).version;
    if (!isNewerVersion(latest, current)) return null;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dismissedKey) == latest) return null;

    final message = (data['message'] as String? ?? '').trim();
    return AppUpdate(
      latest: latest,
      storeUrl: url,
      message: message.isEmpty ? null : message,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[update] check skipped: $e');
    return null;
  }
});

/// Wraps the app and floats a dismissible "update available" card over the top
/// when a newer build is published. Installed once in `MaterialApp.router`'s
/// `builder`, like the offline bar, so every screen gets it.
///
/// "Later" remembers the dismissed version, so it comes back only when an even
/// newer one is published.
class UpdateNudge extends ConsumerStatefulWidget {
  const UpdateNudge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateNudge> createState() => _UpdateNudgeState();
}

class _UpdateNudgeState extends ConsumerState<UpdateNudge> {
  bool _hidden = false;

  Future<void> _later(AppUpdate update) async {
    setState(() => _hidden = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, update.latest);
    } catch (_) {/* shown again next launch — harmless */}
  }

  Future<void> _update(AppUpdate update) async {
    try {
      await launchUrl(Uri.parse(update.storeUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('[update] open store failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(appUpdateProvider).asData?.value;

    return Stack(
      children: [
        widget.child,
        if (update != null && !_hidden)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Material(
                  color: Brand.paper,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Update available · ${update.latest}',
                                  style: tw(FontWeight.w800, 14, Brand.ink)),
                              if (update.message != null) ...[
                                const SizedBox(height: 2),
                                Text(update.message!,
                                    style: tw(FontWeight.w600, 12.5, Brand.sub)),
                              ],
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _later(update),
                          child: Text('Later',
                              style: tw(FontWeight.w700, 13, Brand.sub)),
                        ),
                        TextButton(
                          onPressed: () => _update(update),
                          child: Text('Update',
                              style: tw(FontWeight.w800, 13, Brand.blue)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
