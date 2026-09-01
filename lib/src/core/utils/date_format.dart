const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. "Mon 9 Jun".
String formatShortDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// e.g. "9 Jun 2026".
String formatLongDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// e.g. "4:38 PM".
String formatClockTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

/// "Today · 4:38 PM" / "Yesterday · 4:38 PM" / "Mon 9 Jun · 4:38 PM".
String formatRelativeDateTime(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diffDays = today.difference(day).inDays;
  final label = switch (diffDays) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => formatShortDate(d),
  };
  return '$label · ${formatClockTime(d)}';
}
