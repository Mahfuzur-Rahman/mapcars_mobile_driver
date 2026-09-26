// The X-Ios-Bundle-Identifier header is what lets an *iOS apps*-restricted Maps
// key be used for the Places/Directions web services. If the header and the
// real bundle id ever diverge, Google answers REQUEST_DENIED and address search
// dies on iOS only — invisible on Android and in every widget test. Cheaper to
// catch here than in TestFlight.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/navigate/services/maps_service.dart';

void main() {
  test('kIosBundleId matches the Xcode project', () {
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
        .allMatches(pbxproj)
        .map((m) => m.group(1)!.trim())
        .where((id) => !id.endsWith('.RunnerTests'))
        .toSet();

    expect(ids, isNotEmpty, reason: 'no app bundle id found in project.pbxproj');
    expect(ids, {kIosBundleId},
        reason: 'kIosBundleId is stale: the Xcode project now says $ids');
  });
}
