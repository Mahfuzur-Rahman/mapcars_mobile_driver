import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the slide-out menu drawer is open.
///
/// Lives in its own file so both the drawer itself (`screen_stepper.dart`) and
/// the shared nav widgets that open it (`mc.dart`) can reach it without the two
/// importing each other.
final devDrawerOpenProvider = StateProvider<bool>((ref) => false);

/// Opens the menu drawer. The trigger widgets all funnel through here so the
/// state key stays in one place.
void openMenuDrawer(WidgetRef ref) =>
    ref.read(devDrawerOpenProvider.notifier).state = true;
