import '../../../core/utils/uk_time.dart';
import '../../drive/services/trip_service.dart';

/// The earnings screen's "this week", computed from the driver's own completed
/// trips (`GET /trips/mine`), in integer pence.
///
/// "This week" is the **UK statement week** — Monday 00:00 London to now — so
/// the figure a driver watches build up is the one their next statement
/// settles. It used to be a rolling seven days bucketed by *UTC* weekday, so
/// the M–S bars mixed in last week's days, and a just-after-midnight BST trip
/// landed on the previous day's bar.
///
/// Tips are separate from `driverEarnings` (the API's fare − fee), and are paid
/// to the driver in full, so they are added — the old screen left them out of
/// the headline total and *subtracted* them from the trip-earnings row.
class WeekEarnings {
  const WeekEarnings({
    required this.tripPence,
    required this.tipsPence,
    required this.tripCount,
    required this.dayTotalsPence,
    required this.todayIndex,
  });

  /// Driver share of fares (fare − Mapcars fee), excluding tips.
  final int tripPence;
  final int tipsPence;
  final int tripCount;

  /// Take-home (share + tips) per day, Monday first.
  final List<int> dayTotalsPence;

  /// Today's position in [dayTotalsPence] (Monday = 0), in UK terms.
  final int todayIndex;

  int get totalPence => tripPence + tipsPence;

  factory WeekEarnings.from(List<Trip> trips, {required DateTime now}) {
    final ukNow = toUkTime(now);
    // London wall-clock Monday 00:00, as a "UK fields" value to compare against
    // other toUkTime results.
    final monday = DateTime.utc(ukNow.year, ukNow.month, ukNow.day)
        .subtract(Duration(days: ukNow.weekday - 1));

    var trip = 0, tips = 0, count = 0;
    final days = List<int>.filled(7, 0);
    for (final t in trips) {
      if (t.status != TripStatus.completed) continue;
      final at = toUkTime(t.completedAtUtc ?? t.createdAtUtc);
      if (at.isBefore(monday) || at.isAfter(ukNow)) continue;

      final share = ((t.driverEarnings ?? 0) * 100).round();
      final tip = (t.tipAmount * 100).round();
      trip += share;
      tips += tip;
      count++;
      days[at.weekday - 1] += share + tip;
    }

    return WeekEarnings(
      tripPence: trip,
      tipsPence: tips,
      tripCount: count,
      dayTotalsPence: days,
      todayIndex: ukNow.weekday - 1,
    );
  }
}
