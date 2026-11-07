import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../features/auth/providers/auth_notifier.dart';
import 'mc.dart';
import 'menu_search.dart';
import '../../features/messages/providers/unread_provider.dart';

// Re-exported so the many screens that already import this file for
// `devDrawerOpenProvider` keep working.
export 'drawer_state.dart';

/// One destination in the drawer.
///
/// [icon] does double duty: a non-null named icon (see `mc_icons.dart`) marks
/// the entry as a real, user-facing menu destination. Entries without one are
/// prototype-only steps in the walk-through and are hidden outside dev builds —
/// a customer or driver must never be able to tap straight into `/searching` or
/// `/trip-complete` from a menu.
///
/// [inMenu] `false` keeps a user-facing destination out of the menu list while
/// leaving it findable through the menu's search box — a page people look for
/// that would only clutter the list. [keywords] are the other words someone
/// might type for it ("card" for Payment, "language" for Settings).
class StepRoute {
  const StepRoute(
    this.path,
    this.label, {
    this.category,
    this.icon,
    this.inMenu = true,
    this.keywords = const [],
  });
  final String path;
  final String label;
  final String? category;
  final String? icon;
  final bool inMenu;
  final List<String> keywords;

  bool get isMenuItem => icon != null && inMenu;
  bool get isSearchable => icon != null;
}

/// Shell wrapper that hosts the slide-out navigation menu drawer.
/// Triggered by tapping the top-left menu icon on screens.
///
/// Renders in two modes. In dev (`AppConfig.showDevNav`) it is the prototype
/// walk-through: every screen, numbered, with its route path. In every other
/// build it is a plain user menu — only the destinations tagged with an icon.
/// Either way a search box at the top filters it: the user destinations (and
/// their keywords) in a real build, every screen and route path in dev.
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
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _devMode => AppConfig.showDevNav;

  List<StepRoute> get _items => _devMode
      ? widget.routes
      : widget.routes.where((r) => r.isMenuItem).toList();

  /// What the search box looks through: search-only pages too, never the
  /// prototype steps outside dev.
  List<StepRoute> get _searchPool => _devMode
      ? widget.routes
      : widget.routes.where((r) => r.isSearchable).toList();

  /// Category headers are the prototype's taxonomy ("Onboarding", "Dev Tools"),
  /// so they only make sense alongside the full walk-through list.
  bool _showsCategory(List<StepRoute> items, int i) =>
      _devMode &&
      items[i].category != null &&
      (i == 0 || items[i - 1].category != items[i].category);

  void _close() => ref.read(devDrawerOpenProvider.notifier).state = false;

  /// Every opening starts from the plain menu, keyboard down.
  void _resetSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    _search.clear();
  }

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
    final query = _search.text.trim();
    final hits =
        query.isEmpty ? null : searchMenu(_searchPool, query, matchPath: _devMode);

    ref.listen<bool>(devDrawerOpenProvider, (was, now) {
      if (now && was != true) _revealCurrent(items);
      if (!now && was == true) _resetSearch();
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
              // The drawer sits outside every Scaffold, so nothing else lifts
              // it clear of the keyboard the search box brings up.
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                  children: [
                    _header(context),
                    _searchField(),
                    Expanded(
                      child: hits == null
                          ? ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                if (!_showsCategory(items, i)) return _row(items[i]);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _categoryHeader(items[i].category!),
                                    _row(items[i]),
                                  ],
                                );
                              },
                            )
                          : hits.isEmpty
                              ? _noResults(query)
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  itemCount: hits.length,
                                  itemBuilder: (context, i) => _row(
                                    hits[i].route,
                                    hint: hits[i].matchedKeyword,
                                  ),
                                ),
                    ),
                    _footer(context),
                  ],
                ),
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

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: McField(
          icon: 'search',
          editable: true,
          controller: _search,
          placeholder: _devMode ? 'Search screens' : 'What are you looking for?',
          suffix: _search.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _search.clear,
                  icon: const Icon(Icons.close_rounded, color: Brand.sub, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  tooltip: 'Clear search',
                ),
        ),
      );

  Widget _noResults(String query) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Ico('search', size: 28, color: Brand.sub),
          const SizedBox(height: 10),
          Text(
            'Nothing matches “$query”',
            textAlign: TextAlign.center,
            style: tw(FontWeight.w800, 14, Brand.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Check the spelling or try a shorter word.',
            textAlign: TextAlign.center,
            style: tw(FontWeight.w600, 13, Brand.sub),
          ),
        ],
      );

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

  /// [hint] is the search keyword that found this row, shown under the label
  /// ("Language" under Settings) so the result explains itself.
  Widget _row(StepRoute item, {String? hint}) {
    final isSelected = item.path == widget.current;
    // Walk-through numbering stays put while the list is filtered.
    final number = widget.routes.indexOf(item) + 1;
    final subtitle = _devMode ? (hint ?? item.path) : hint;

    return SizedBox(
      height: _rowHeight,
      child: Material(
        color: isSelected ? Brand.blue.withValues(alpha: 0.10) : Colors.transparent,
        child: InkWell(
          onTap: () {
            _close();
            // No `extra`: the trip screens resolve the driver's real trip
            // themselves (see `TripGate`). This used to hand them a demo trip,
            // which is why every step of the walk-through showed the same
            // invented customer, route and fare.
            context.go(item.path);
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
                      if (subtitle != null)
                        Text(
                          _devMode || subtitle.isEmpty
                              ? subtitle
                              : subtitle[0].toUpperCase() + subtitle.substring(1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tw(FontWeight.w500, 11, Brand.sub),
                        ),
                    ],
                  ),
                ),
                if (item.path == '/messages')
                  Builder(builder: (_) {
                    final n = ref.watch(unreadProvider.select((s) => s.total));
                    return n == 0
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: McCountPill(n),
                          );
                  }),
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
