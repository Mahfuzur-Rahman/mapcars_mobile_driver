import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../features/auth/providers/auth_notifier.dart';
import '../../features/drive/demo_trip.dart';
import 'mc.dart';

// Re-exported so the many screens that already import this file for
// `devDrawerOpenProvider` keep working.
export 'drawer_state.dart';

/// Routes that render a real trip-flow screen and need a demo [Trip] to show
/// their real map/data instead of falling back to static walkthrough art.
const _routesNeedingDemoTrip = {
  '/request',
  '/nav-pickup',
  '/arrived',
  '/driving',
  '/trip-complete',
  '/chat',
};

/// One destination in the drawer.
///
/// [icon] does double duty: a non-null named icon (see `mc_icons.dart`) marks
/// the entry as a real, user-facing menu destination. Entries without one are
/// prototype-only steps in the walk-through and are hidden outside dev builds —
/// a rider or driver must never be able to tap straight into `/searching` or
/// `/trip-complete` from a menu.
class StepRoute {
  const StepRoute(this.path, this.label, {this.category, this.icon});
  final String path;
  final String label;
  final String? category;
  final String? icon;

  bool get isMenuItem => icon != null;
}

/// Shell wrapper that hosts the slide-out navigation menu drawer.
/// Triggered by tapping the top-left menu icon on screens.
///
/// Renders in two modes. In dev (`AppConfig.showDevNav`) it is the prototype
/// walk-through: every screen, numbered, with its route path. In every other
/// build it is a plain user menu — only the destinations tagged with an icon.
class ScreenStepper extends ConsumerStatefulWidget {
  const ScreenStepper({
    super.key,
    required this.routes,
    required this.current,
    required this.child,
  });

  final List<StepRoute> routes;
  final String current;
  final Widget child;

  @override
  ConsumerState<ScreenStepper> createState() => _ScreenStepperState();
}

class _ScreenStepperState extends ConsumerState<ScreenStepper> {
  static const double _panelWidth = 300;
  static const double _rowHeight = 56;
  static const double _categoryHeight = 35;
  static const Duration _slide = Duration(milliseconds: 240);

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _devMode => AppConfig.showDevNav;

  List<StepRoute> get _items => _devMode
      ? widget.routes
      : widget.routes.where((r) => r.isMenuItem).toList();

  /// Category headers are the prototype's taxonomy ("Onboarding", "Dev Tools"),
  /// so they only make sense alongside the full walk-through list.
  bool _showsCategory(List<StepRoute> items, int i) =>
      _devMode &&
      items[i].category != null &&
      (i == 0 || items[i - 1].category != items[i].category);

  void _close() => ref.read(devDrawerOpenProvider.notifier).state = false;

  Future<void> _logout() async {
    _close();
    await ref.read(authNotifierProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/intro');
  }

  /// Bring the current screen's row into view. Row heights are fixed, so the
  /// offset is exact — without this the drawer always opens showing item 1,
  /// which in dev mode can be twenty-odd rows above where you actually are.
  void _revealCurrent(List<StepRoute> items) {
    final index = items.indexWhere((r) => r.path == widget.current);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      var offset = 0.0;
      for (var i = 0; i <= index; i++) {
        if (_showsCategory(items, i)) offset += _categoryHeight;
        if (i < index) offset += _rowHeight;
      }
      _scroll.jumpTo(
        (offset - 160).clamp(0.0, _scroll.position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final isOpen = ref.watch(devDrawerOpenProvider);

    ref.listen<bool>(devDrawerOpenProvider, (was, now) {
      if (now && was != true) _revealCurrent(items);
    });

    return PopScope(
      // Back should dismiss the drawer, not pop the route out from under it.
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),

          // Backdrop — fades in step with the panel rather than snapping to
          // 50% black while the panel is still sliding.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !isOpen,
              child: AnimatedOpacity(
                duration: _slide,
                curve: Curves.easeOutCubic,
                opacity: isOpen ? 1 : 0,
                child: GestureDetector(
                  onTap: _close,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.black.withValues(alpha: 0.50)),
                ),
              ),
            ),
          ),

          // Slide-out left menu drawer
          AnimatedPositioned(
            duration: _slide,
            curve: Curves.easeOutCubic,
            left: isOpen ? 0 : -(_panelWidth + 20),
            top: 0,
            bottom: 0,
            width: _panelWidth,
            child: Material(
              elevation: 16,
              color: Brand.bg,
              child: Column(
                children: [
                  _header(context),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        if (!_showsCategory(items, i)) return _row(items[i], i + 1);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _categoryHeader(items[i].category!),
                            _row(items[i], i + 1),
                          ],
                        );
                      },
                    ),
                  ),
                  _footer(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final index = widget.routes.indexWhere((r) => r.path == widget.current);
    final currentRoute = index >= 0 ? widget.routes[index] : null;

    return Container(
      width: double.infinity,
      // The status-bar inset is padded here rather than by wrapping the panel
      // in a SafeArea, so the gradient bleeds under the notch instead of
      // leaving a grey Brand.bg band above a floating coloured header.
      padding: EdgeInsets.fromLTRB(
        16,
        20 + MediaQuery.paddingOf(context).top,
        12,
        18,
      ),
      decoration: const BoxDecoration(gradient: Brand.gradBlueGreen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The logo artwork is brand blue and green, which is exactly the
              // gradient behind it — knock it out to solid white so it reads.
              Expanded(
                child: Image.asset(
                  'assets/images/logo-transparent.png',
                  height: 46,
                  alignment: Alignment.centerLeft,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              IconButton(
                onPressed: _close,
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: 'Close menu',
              ),
            ],
          ),
          // The "which screen am I on" pill is a prototype aid.
          if (_devMode) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_checked_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${currentRoute?.label ?? "Screen"} — ${widget.current}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryHeader(String category) => SizedBox(
        height: _categoryHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                category.toUpperCase(),
                style: tw(FontWeight.w800, 11, Brand.sub, 0.8),
              ),
            ),
          ),
        ),
      );

  Widget _row(StepRoute item, int number) {
    final isSelected = item.path == widget.current;

    return SizedBox(
      height: _rowHeight,
      child: Material(
        color: isSelected ? Brand.blue.withValues(alpha: 0.10) : Colors.transparent,
        child: InkWell(
          onTap: () {
            _close();
            context.go(
              item.path,
              extra: _routesNeedingDemoTrip.contains(item.path) ? demoTrip : null,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Brand.blue : Brand.fill,
                  ),
                  child: _devMode
                      ? Text(
                          '$number',
                          style: tw(FontWeight.w800, 11,
                              isSelected ? Colors.white : Brand.sub),
                        )
                      : Ico(item.icon!,
                          size: 16, color: isSelected ? Colors.white : Brand.sub),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tw(
                          isSelected ? FontWeight.w900 : FontWeight.w700,
                          14,
                          isSelected ? Brand.blue : Brand.ink,
                        ),
                      ),
                      // Raw route paths are a prototype aid, and Brand.faint on
                      // Brand.bg only reaches ~2.6:1 — Brand.sub clears 4.5:1.
                      if (_devMode)
                        Text(
                          item.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tw(FontWeight.w500, 11, Brand.sub),
                        ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: isSelected ? Brand.blue : Brand.sub,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) => Container(
        width: double.infinity,
        // Same trick as the header: absorb the gesture-bar inset inside the
        // white footer so no grey strip shows beneath it.
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: Brand.paper,
          border: Border(top: BorderSide(color: Brand.fill)),
        ),
        child: McDangerButton('Log out', icon: 'logout', onTap: _logout),
      );
}
