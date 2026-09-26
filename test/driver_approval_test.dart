// The approval gate fails closed.
//
// Going online and seeing the requests board require an admin to have approved
// the driver. `DriverApproval.unknown` used to carry `status: 'Approved'` so the
// offline demo session could reach the board — which also meant a signed-out,
// still-loading or offline app treated "don't know" as "cleared to work". The
// API still refused, but the app offered a switch it had no business offering.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/auth/providers/driver_approval_provider.dart';

void main() {
  test('an unknown approval can not work', () {
    expect(DriverApproval.unknown.canWork, isFalse);
    expect(DriverApproval.unknown.isKnown, isFalse);
  });

  test('only the API saying Approved lets a driver work', () {
    const approved = DriverApproval(status: 'Approved', isOnline: false);
    expect(approved.canWork, isTrue);
    expect(approved.isKnown, isTrue);

    for (final status in ['PendingApproval', 'Suspended', 'Rejected', '']) {
      final d = DriverApproval(status: status, isOnline: false);
      expect(d.canWork, isFalse, reason: status);
      expect(d.isKnown, isTrue, reason: status);
    }
  });

  test('unknown explains itself instead of claiming a review is pending', () {
    expect(DriverApproval.unknown.blockedCopy.$1, 'Checking your account');
  });

  test('no session resolves to unknown, never approved', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final approval = await container.read(driverApprovalProvider.future);
    expect(approval.canWork, isFalse);
    expect(approval.isKnown, isFalse);
  });
}
