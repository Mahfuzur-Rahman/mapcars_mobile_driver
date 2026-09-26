// UK wall-clock time without a timezone database.
//
// Statements are cut on London weeks (Mon 00:00 → next Mon 00:00), and a
// driver's phone is not guaranteed to be set to London — so `toLocal()` could
// put a week's Monday on the previous Sunday. The UK rule is simple enough to
// carry: GMT, plus one hour from 01:00 UTC on the last Sunday of March until
// 01:00 UTC on the last Sunday of October.

/// Whether [instant] falls inside British Summer Time.
bool isBritishSummerTime(DateTime instant) {
  final utc = instant.toUtc();
  final start = _lastSundayAt1amUtc(utc.year, 3);
  final end = _lastSundayAt1amUtc(utc.year, 10);
  return !utc.isBefore(start) && utc.isBefore(end);
}

/// [instant] as London wall-clock time. The result is a `DateTime.utc` whose
/// *fields* are London's (so it formats the same on any phone) — read its date
/// and time, don't treat it as an instant.
DateTime toUkTime(DateTime instant) {
  final utc = instant.toUtc();
  return isBritishSummerTime(utc) ? utc.add(const Duration(hours: 1)) : utc;
}

DateTime _lastSundayAt1amUtc(int year, int month) {
  final lastDay = DateTime.utc(year, month + 1, 0); // day 0 = last of [month]
  final sunday = lastDay.subtract(Duration(days: lastDay.weekday % 7));
  return DateTime.utc(sunday.year, sunday.month, sunday.day, 1);
}
