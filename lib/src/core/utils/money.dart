/// Formats an integer amount in **pence** as a GBP string, e.g. 978 -> "£9.78".
///
/// Money is carried as integer pence (never a double) to avoid floating-point
/// rounding errors — only formatted at the edge.
String formatGbp(int pence) => '£${(pence / 100).toStringAsFixed(2)}';
