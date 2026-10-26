// The same rule as the web (web/src/lib/phone.ts) and the customer app. The app
// used to glue "+44" to "07400…", producing "+4407400…": a different account
// from the same person signing up on the web.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/utils/uk_phone.dart';

void main() {
  test('every way of typing a UK mobile gives the same number', () {
    for (final typed in [
      '07400 123456',
      '7400 123456',
      '+44 7400 123456',
      '447400123456',
      '(07400) 123-456',
    ]) {
      expect(ukMobileE164(typed), '+447400123456', reason: typed);
    }
  });

  test('anything but a UK mobile is refused', () {
    for (final typed in ['', '123', '020 7946 0018', '07400 12345', '06 12 34 56 78']) {
      expect(ukMobileE164(typed), isNull, reason: typed);
    }
  });

  test('nationalPart refills the field next to the fixed +44', () {
    expect(nationalPart('+447400123456'), '7400123456');
    expect(nationalPart('7400123456'), '7400123456');
  });
}
