import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/mc.dart';
import '../models/statement.dart';
import '../services/statement_service.dart';
import 'statements_screen.dart';

/// One week's statement: the net answer first, then how it adds up, then every
/// trip that went into it. Every figure is the API's — nothing is recomputed
/// here, so the screen can never disagree with what Mapcars actually pays.
class StatementDetailScreen extends ConsumerWidget {
  const StatementDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(statementDetailProvider(id));

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(statementDetailProvider(id).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const McNavHeader(title: 'Statement', fallback: '/statements'),
                const SizedBox(height: 16),
                detail.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => StatementErrorState(
                    message: friendlyError(e, "Couldn't load this statement."),
                    onRetry: () => ref.invalidate(statementDetailProvider(id)),
                  ),
                  data: (d) => _Body(detail: d),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});
  final StatementDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    final direction = netDirection(s.netPence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The answer, first.
        McCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.periodLabel,
                        style: tw(FontWeight.w800, 13, Brand.sub)),
                  ),
                  StatementStatusPill(settled: s.isSettled),
                ],
              ),
              const SizedBox(height: 8),
              McTitle(netHeadline(s.netPence), size: 20),
              if (direction == NetDirection.driverOwes) ...[
                const SizedBox(height: 6),
                Text(
                  'You kept the full fare on your cash trips, so the Mapcars '
                  'fee on those is due back.',
                  style: tw(FontWeight.w600, 12.5, Brand.sub),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // How it adds up.
        McCard(
          padding: 14,
          child: Column(
            children: [
              _Row('Completed trips', '${s.tripCount}'),
              _Row('Fares', formatGbp(s.grossFaresPence)),
              _Row('Tips', formatGbp(s.tipsPence)),
              _Row('Mapcars fee', '−${formatGbp(s.commissionPence)}'),
              _Row('Your earnings', formatGbp(s.driverEarningsPence), strong: true),
              const _Divider(),
              _Row('Card trips — paid to you', formatGbp(s.cardPayablePence)),
              _Row('Fee on cash trips — owed',
                  '−${formatGbp(s.cashCommissionOwedPence)}'),
              const _Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text('Net', style: tw(FontWeight.w900, 15)),
                  ),
                  SignedAmount(s.netPence, size: 17),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('TRIPS', style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
        const SizedBox(height: 8),
        if (detail.lines.isEmpty)
          Text('No trips on this statement.',
              style: tw(FontWeight.w700, 13, Brand.sub))
        else
          McCard(
            padding: 4,
            child: Column(
              children: [
                for (int i = 0; i < detail.lines.length; i++)
                  _LineTile(
                    line: detail.lines[i],
                    divider: i < detail.lines.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: tw(strong ? FontWeight.w900 : FontWeight.w700, 14,
                      strong ? Brand.ink : Brand.sub)),
            ),
            Text(value,
                style: tw(FontWeight.w900, 14,
                    strong ? Brand.green : Brand.ink)),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: Brand.fill,
      );
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.divider});
  final StatementLine line;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: Brand.fill))
            : null,
      ),
      child: Row(
        children: [
          Ico(line.isCash ? 'cash' : 'card', size: 20, color: Brand.sub),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.whenLabel, style: tw(FontWeight.w800, 14)),
                const SizedBox(height: 2),
                Text(line.detailLabel,
                    style: tw(FontWeight.w600, 12, Brand.sub)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SignedAmount(line.amountPence),
        ],
      ),
    );
  }
}
