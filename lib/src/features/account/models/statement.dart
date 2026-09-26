import '../../../core/utils/date_format.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/uk_time.dart';

/// Reads a money field as integer pence. The API sends integers; a stray
/// fractional value is rounded rather than carried as a double, because every
/// total on a statement is a sum of these and must add up to the penny.
int _pence(Map<String, dynamic> j, String key) =>
    (j[key] as num?)?.round() ?? 0;

DateTime _utc(Map<String, dynamic> j, String key) =>
    DateTime.parse(j[key] as String).toUtc();

/// One UK week (Mon 00:00 London → next Mon 00:00) of a driver's money, as
/// settled between them and Mapcars. Mirrors the API's statement summary.
///
/// All money is **integer pence**. Unlike `Trip`'s legacy double fields, these
/// are totals the driver may compare against their bank — no float drift.
class Statement {
  const Statement({
    required this.id,
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.tripCount,
    required this.grossFaresPence,
    required this.tipsPence,
    required this.commissionPence,
    required this.driverEarningsPence,
    required this.cardPayablePence,
    required this.cashCommissionOwedPence,
    required this.netPence,
    required this.status,
    required this.createdAtUtc,
  });

  final String id;
  final DateTime periodStartUtc;

  /// Exclusive: the Monday 00:00 that *closes* the week.
  final DateTime periodEndUtc;
  final int tripCount;
  final int grossFaresPence;
  final int tipsPence;
  final int commissionPence;
  final int driverEarningsPence;

  /// What card trips earned the driver (their share + tips) — Mapcars owes it.
  final int cardPayablePence;

  /// Commission on cash trips, where the driver already holds the whole fare.
  final int cashCommissionOwedPence;

  /// Signed, platform → driver: positive means Mapcars pays, negative means the
  /// driver owes, zero means nothing moves.
  final int netPence;

  /// "Issued" | "Settled".
  final String status;
  final DateTime createdAtUtc;

  bool get isSettled => status.trim().toLowerCase() == 'settled';

  /// "Mon 7 Sep – Sun 13 Sep", in UK dates. The end is exclusive, so the last
  /// day shown is the day before it.
  String get periodLabel {
    final start = toUkTime(periodStartUtc);
    final end = toUkTime(periodEndUtc).subtract(const Duration(days: 1));
    return '${formatShortDate(start)} – ${formatShortDate(end)}';
  }

  factory Statement.fromJson(Map<String, dynamic> j) => Statement(
        id: j['id'].toString(),
        periodStartUtc: _utc(j, 'periodStartUtc'),
        periodEndUtc: _utc(j, 'periodEndUtc'),
        tripCount: (j['tripCount'] as num?)?.toInt() ?? 0,
        grossFaresPence: _pence(j, 'grossFaresPence'),
        tipsPence: _pence(j, 'tipsPence'),
        commissionPence: _pence(j, 'commissionPence'),
        driverEarningsPence: _pence(j, 'driverEarningsPence'),
        cardPayablePence: _pence(j, 'cardPayablePence'),
        cashCommissionOwedPence: _pence(j, 'cashCommissionOwedPence'),
        netPence: _pence(j, 'netPence'),
        status: j['status'] as String? ?? 'Issued',
        createdAtUtc: _utc(j, 'createdAtUtc'),
      );
}

/// One completed trip on a statement.
class StatementLine {
  const StatementLine({
    required this.tripId,
    required this.completedAtUtc,
    required this.paymentMethod,
    required this.farePence,
    required this.tipPence,
    required this.commissionPence,
    required this.driverEarningsPence,
    required this.amountPence,
  });

  final String tripId;
  final DateTime completedAtUtc;

  /// "Cash" | "Card".
  final String paymentMethod;
  final int farePence;
  final int tipPence;
  final int commissionPence;
  final int driverEarningsPence;

  /// Signed, platform → driver. Card: +(driver share + tip). Cash: −commission,
  /// because the driver already collected the whole fare in person.
  final int amountPence;

  bool get isCash => paymentMethod.trim().toLowerCase() == 'cash';

  /// "Mon 7 Sep · 4:38 PM", UK time.
  String get whenLabel {
    final at = toUkTime(completedAtUtc);
    return '${formatShortDate(at)} · ${formatClockTime(at)}';
  }

  /// What happened to the money on this trip, in the driver's terms.
  String get detailLabel {
    if (isCash) return 'Cash · you collected ${formatGbp(farePence + tipPence)}';
    final tip = tipPence > 0 ? ' + ${formatGbp(tipPence)} tip' : '';
    return 'Card · fare ${formatGbp(farePence)}$tip';
  }

  factory StatementLine.fromJson(Map<String, dynamic> j) => StatementLine(
        tripId: j['tripId'].toString(),
        completedAtUtc: _utc(j, 'completedAtUtc'),
        paymentMethod: j['paymentMethod'] as String? ?? '',
        farePence: _pence(j, 'farePence'),
        tipPence: _pence(j, 'tipPence'),
        commissionPence: _pence(j, 'commissionPence'),
        driverEarningsPence: _pence(j, 'driverEarningsPence'),
        amountPence: _pence(j, 'amountPence'),
      );
}

class StatementDetail {
  const StatementDetail({required this.summary, required this.lines});
  final Statement summary;
  final List<StatementLine> lines;

  factory StatementDetail.fromJson(Map<String, dynamic> j) => StatementDetail(
        summary: Statement.fromJson(j['summary'] as Map<String, dynamic>),
        lines: ((j['lines'] as List<dynamic>?) ?? const [])
            .map((e) => StatementLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Which way a statement's net moves.
enum NetDirection { mapcarsPays, driverOwes, nothingDue }

NetDirection netDirection(int netPence) => netPence > 0
    ? NetDirection.mapcarsPays
    : (netPence < 0 ? NetDirection.driverOwes : NetDirection.nothingDue);

/// The one sentence that answers "so who pays whom?".
String netHeadline(int netPence) => switch (netDirection(netPence)) {
      NetDirection.mapcarsPays => 'Mapcars pays you ${formatGbp(netPence)}',
      NetDirection.driverOwes =>
        'You owe Mapcars ${formatGbp(-netPence)} commission on cash trips',
      NetDirection.nothingDue => 'Nothing due — this week is settled',
    };
