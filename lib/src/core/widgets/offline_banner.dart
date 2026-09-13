import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity.dart';
import 'mc.dart';

/// Wraps the whole app and shows a slim bar while the device has no network.
///
/// Installed once via `MaterialApp.router`'s `builder`, so every screen gets it
/// without opting in — the screens that matter most here (the dispatch board,
/// mid-job) are exactly the ones nobody would remember to annotate.
///
/// It overlays rather than pushing content down: inserting a bar into the
/// layout would shift every screen underneath it the moment the signal drops,
/// and a map jumping under the driver's thumb while they are driving is its
/// own small bug. It is also
/// wrapped in [IgnorePointer], so it can never swallow a tap meant for the UI
/// beneath it.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);

    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              offset: online ? const Offset(0, -1) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: online ? 0 : 1,
                child: const _OfflineBar(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Brand.ink,
            borderRadius: BorderRadius.circular(12),
            boxShadow: Brand.floatShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  // Names the consequence a driver actually cares about: the
                  // dispatch board is pushed, so an offline phone quietly stops
                  // being offered work rather than showing an obviously empty
                  // board. A driver could otherwise sit "online" earning
                  // nothing and assume it was a quiet night.
                  "No connection — you won't see new jobs",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tw(FontWeight.w800, 13, Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
