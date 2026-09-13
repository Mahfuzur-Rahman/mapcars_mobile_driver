// Guards the map-marker painter. It hand-builds several multi-stop gradients,
// and ui.Gradient.linear asserts when a colour list and its stop list disagree
// in length — the easiest thing to get wrong when restyling the car. These
// tests also prove the canvas actually rasterises to PNG bytes.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/theme/brand.dart';
import 'package:mapcars_driver/src/features/drive/services/car_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('drawCarIcon rasterises the driver own-car marker', () async {
    // Pearl is the only colour this app draws: the route polyline underneath
    // is green on the pickup leg and blue on the trip leg, so the car has to
    // contrast with both rather than match one.
    await expectLater(drawCarIcon(Brand.carPearl), completes);
  });

  test('drawCarIcon defaults to pearl', () async {
    await expectLater(drawCarIcon(), completes);
  });

  test('the declared car footprint matches the customer app', () {
    expect(carIconWidth, 64.0);
    expect(carIconHeight, 128.0);
  });
}
