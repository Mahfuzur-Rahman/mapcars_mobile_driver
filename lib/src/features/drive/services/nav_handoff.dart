import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/mc.dart';

/// Hands turn-by-turn navigation off to the driver's own navigation app.
///
/// Mapcars deliberately doesn't ship its own voice-guided turn-by-turn: drivers
/// already have Google Maps or Waze set up the way they like (traffic, tolls,
/// bus lanes, voice), and matching a dedicated navigation SDK's re-routing and
/// lane guidance isn't a good use of the platform's effort. The in-app map shows
/// the route, live ETA and distance; this opens the real navigator for the
/// driving itself, which is what Uber and Bolt do too.
class NavHandoff {
  const NavHandoff._();

  /// Shows the app picker, then launches the chosen navigator toward
  /// ([lat], [lng]). Returns false if the driver dismissed the sheet or nothing
  /// could be launched (with a message already shown).
  static Future<bool> start(
    BuildContext context, {
    required double lat,
    required double lng,
    String? label,
  }) async {
    final choice = await showModalBottomSheet<_NavApp>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NavAppSheet(label: label),
    );
    if (choice == null || !context.mounted) return false;

    final launched = await _launch(choice, lat, lng, label);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${choice.label} isn\'t installed on this device.'),
        ));
    }
    return launched;
  }

  static Future<bool> _launch(
      _NavApp app, double lat, double lng, String? label) async {
    for (final uri in _urisFor(app, lat, lng, label)) {
      try {
        if (await canLaunchUrl(uri)) {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            return true;
          }
        }
      } catch (_) {
        // Try the next candidate rather than failing the whole handoff.
      }
    }
    return false;
  }

  /// Candidate URIs in order of preference: the app's own scheme first (opens
  /// the installed app directly), then a universal https link as the fallback.
  static List<Uri> _urisFor(_NavApp app, double lat, double lng, String? label) {
    switch (app) {
      case _NavApp.googleMaps:
        return [
          // `google.navigation:` starts turn-by-turn immediately on Android;
          // `comgooglemaps://` is the iOS equivalent scheme.
          if (Platform.isAndroid)
            Uri.parse('google.navigation:q=$lat,$lng&mode=d'),
          if (Platform.isIOS)
            Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving'),
          Uri.parse(
              'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving&dir_action=navigate'),
        ];
      case _NavApp.waze:
        return [
          Uri.parse('waze://?ll=$lat,$lng&navigate=yes'),
          Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
        ];
      case _NavApp.appleMaps:
        return [Uri.parse('http://maps.apple.com/?daddr=$lat,$lng&dirflg=d')];
    }
  }
}

enum _NavApp {
  googleMaps('Google Maps', Icons.map_outlined),
  waze('Waze', Icons.navigation_outlined),
  appleMaps('Apple Maps', Icons.explore_outlined);

  const _NavApp(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _NavAppSheet extends StatelessWidget {
  const _NavAppSheet({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    // Apple Maps only exists on iOS; offering it on Android is a dead option.
    final apps = [
      _NavApp.googleMaps,
      _NavApp.waze,
      if (Platform.isIOS) _NavApp.appleMaps,
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Navigate with', style: tw(FontWeight.w900, 16, Brand.ink)),
            if (label != null) ...[
              const SizedBox(height: 3),
              Text(label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tw(FontWeight.w600, 12.5, Brand.sub)),
            ],
            const SizedBox(height: 14),
            for (final app in apps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context, app),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Brand.fill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(app.icon, size: 21, color: Brand.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(app.label,
                              style: tw(FontWeight.w800, 14.5, Brand.ink)),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 20, color: Brand.faint),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
