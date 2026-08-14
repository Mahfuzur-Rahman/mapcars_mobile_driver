import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/current_location_map.dart';
import '../../../core/widgets/mc.dart';
import '../demo_trip.dart';
import 'widgets/request_card.dart';

/// Dev-only preview of the "incoming request" moment. In production this is
/// never a route — it's the real [RequestCard] overlaid live on
/// `DriverHomeScreen`, fed by `DispatchBoardController`. This route exists
/// purely so the dev "Screens" walkthrough can still step through that
/// moment, using the same real map and the same real card, just fed
/// [demoTrip] instead of a live dispatch push.
class RequestPreviewScreen extends StatelessWidget {
  const RequestPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CurrentLocationMap()),
          const Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: McFloatingNav(showBack: false, showHome: false),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: RequestCard(
              trip: demoTrip,
              busy: false,
              moreCount: 0,
              onAccept: () => context.go('/nav-pickup', extra: demoTrip),
              onIgnore: () => context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }
}
