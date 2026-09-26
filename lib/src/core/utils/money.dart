/// Formats an integer amount in **pence** as a GBP string, e.g. 978 -> "£9.78".
///
/// Money is carried as integer pence (never a double) to avoid floating-point
/// rounding errors — only formatted at the edge.
String formatGbp(int pence) => '£${(pence / 100).toStringAsFixed(2)}';

/// Signed GBP for money that can flow either way, e.g. 978 -> "+£9.78",
/// -150 -> "−£1.50", 0 -> "£0.00". Uses a real minus sign (U+2212), which
/// reads correctly aloud and doesn't wrap like a hyphen.
String formatSignedGbp(int pence) {
  if (pence == 0) return formatGbp(0);
  return '${pence > 0 ? '+' : '−'}${formatGbp(pence.abs())}';
}
