import 'screen_stepper.dart' show StepRoute;

/// One search result in the menu drawer: the destination, plus the keyword
/// that matched when it wasn't the label itself — shown under the label so
/// "language" landing on Settings explains itself.
class MenuHit {
  const MenuHit(this.route, {this.matchedKeyword});
  final StepRoute route;
  final String? matchedKeyword;
}

/// Filters [routes] for what the user typed into the menu's search box.
///
/// Case-insensitive substring match, ranked: label starts with the query, then
/// a word in the label does, then the label contains it, then a keyword starts
/// with it / contains it, then (only when [matchPath], i.e. the dev
/// walk-through) the route path contains it. Ties keep the menu's own order.
/// An empty query returns nothing — the caller shows the plain menu instead.
List<MenuHit> searchMenu(
  List<StepRoute> routes,
  String query, {
  bool matchPath = false,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final scored = <(int, int, MenuHit)>[];
  for (var i = 0; i < routes.length; i++) {
    final route = routes[i];
    final label = route.label.toLowerCase();

    int? score;
    String? keyword;
    if (label.startsWith(q)) {
      score = 0;
    } else if (label.split(' ').any((w) => w.startsWith(q))) {
      score = 1;
    } else if (label.contains(q)) {
      score = 2;
    } else {
      for (final k in route.keywords) {
        final kw = k.toLowerCase();
        final rank = kw.split(' ').any((w) => w.startsWith(q))
            ? 3
            : kw.contains(q)
                ? 4
                : null;
        if (rank != null && (score == null || rank < score)) {
          score = rank;
          keyword = k;
        }
      }
      if (score == null && matchPath && route.path.toLowerCase().contains(q)) {
        score = 5;
      }
    }

    if (score != null) {
      scored.add((score, i, MenuHit(route, matchedKeyword: keyword)));
    }
  }

  scored.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return [for (final s in scored) s.$3];
}
