import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/updates/update_nudge.dart';

void main() {
  group('isNewerVersion', () {
    test('newer patch / minor / major', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });
    test('compares numbers, not strings', () {
      expect(isNewerVersion('0.1.10', '0.1.9'), isTrue);
      expect(isNewerVersion('0.1.9', '0.1.10'), isFalse);
    });
    test('equal or older is not an update', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
      expect(isNewerVersion('0.9.0', '1.0.0'), isFalse);
    });
    test('missing parts count as zero', () {
      expect(isNewerVersion('1.2', '1.1.5'), isTrue);
    });
    test('garbage never nags', () {
      expect(isNewerVersion('', '1.0.0'), isFalse);
      expect(isNewerVersion('1.x.0', '1.0.0'), isFalse);
      expect(isNewerVersion('2.0.0', 'abc'), isFalse);
    });
  });
}
