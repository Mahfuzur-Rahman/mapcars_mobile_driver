// Google sign-in on iOS is configured entirely in Info.plist: the plugin drops
// the Dart serverClientId when no iOS client ID is passed alongside it. Every
// mistake below compiles, passes on Android, and only shows on an iPhone, as a
// crash (no client ID / URL scheme) or as the API rejecting the token (wrong
// server client or project). Cheaper to catch here than in TestFlight.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _suffix = '.apps.googleusercontent.com';

String? _plistString(String plist, String key) => RegExp(
      '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
    ).firstMatch(plist)?.group(1)?.trim();

String _project(String clientId) => clientId.split('-').first;

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final clientId = _plistString(plist, 'GIDClientID');
  final serverClientId = _plistString(plist, 'GIDServerClientID');

  test('GIDClientID is an OAuth client ID', () {
    expect(clientId, isNotNull, reason: 'Info.plist has no GIDClientID');
    expect(clientId, endsWith(_suffix));
  });

  test('the reversed client ID is registered as a URL scheme', () {
    final reversed =
        'com.googleusercontent.apps.${clientId!.substring(0, clientId.length - _suffix.length)}';
    final schemes = RegExp(r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
            dotAll: true)
        .allMatches(plist)
        .expand((m) => RegExp(r'<string>([^<]*)</string>')
            .allMatches(m.group(1)!)
            .map((s) => s.group(1)!.trim()))
        .toSet();
    expect(schemes, contains(reversed),
        reason: 'GoogleSignIn raises (and the app crashes) without this scheme');
  });

  test('GIDServerClientID is a different client in the same Cloud project', () {
    expect(serverClientId, isNotNull,
        reason: 'without it the token audience is the iOS client and the API rejects it');
    expect(serverClientId, endsWith(_suffix));
    expect(serverClientId, isNot(clientId));
    expect(_project(serverClientId!), _project(clientId!),
        reason: 'Google only issues a token for the server client when both '
            'clients live in the same Cloud project');
  });
}
