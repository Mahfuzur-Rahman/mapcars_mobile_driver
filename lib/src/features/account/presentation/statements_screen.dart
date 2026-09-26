import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/mc.dart';
import '../models/statement.dart';
import '../services/statement_service.dart';

/// Weekly statements: the honest answer to "when do I get paid, and how much".
///
/// This replaces the earnings screen's old "Instant Cash Out", which confirmed
/// a bank transfer that never happened. Money between a driver and Mapcars
/// moves once a week, netted: card trips are owed to the driver, commission on
/// cash trips is owed by them, and the statement says which way the difference
/// goes.
class StatementsScreen extends ConsumerWidget {
  const StatementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statements = ref.watch(statementsProvider);

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(statementsProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const McNavHeader(title: 'Statements', fallback: '/earnings'),
                const SizedBox(height: 12),
                Text(
                  'One statement per week, Monday to Sunday. Card trips are '
                  'paid to you; commission on cash trips is taken off.',
                  style: tw(FontWeight.w600, 13, Brand.sub),
                ),
                const SizedBox(height: 16),
                statements.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => StatementErrorState(
                    message: friendlyError(e, "Couldn't load your statements."),
                    onRetry: () => ref.invalidate(statementsProvider),
                  ),
                  data: (list) => list.isEmpty
                      ? const _EmptyState()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final s in list) ...[
                              StatementCard(
                                statement: s,
                                onTap: () => context.push('/statements/${s.id}'),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One week in the list: when, how many trips, and who pays whom.
class StatementCard extends StatelessWidget {
  const StatementCard({super.key, required this.statement, this.onTap});

  final Statement statement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = statement;
    final headline = netHeadline(s.netPence);
    return mcTapSemantics(
      label: '${s.periodLabel}. $headline. ${s.status}.',
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: McCard(
          padding: 14,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.periodLabel, style: tw(FontWeight.w900, 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${s.tripCount} ${s.tripCount == 1 ? 'trip' : 'trips'}',
                      style: tw(FontWeight.w600, 12.5, Brand.sub),
                    ),
                    const SizedBox(height: 8),
                    Text(headline,
                        style: tw(FontWeight.w800, 13.5,
                            netColor(netDirection(s.netPence)))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatementStatusPill(settled: s.isSettled),
                  const SizedBox(height: 10),
                  const Ico('chevR', size: 20, color: Brand.faint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green when Mapcars pays, amber when the driver owes, grey when nothing
/// moves. Owing commission is routine for a cash driver, so never the error red.
Color netColor(NetDirection d) => switch (d) {
      NetDirection.mapcarsPays => Brand.green,
      NetDirection.driverOwes => Brand.star,
      NetDirection.nothingDue => Brand.sub,
    };

class StatementStatusPill extends StatelessWidget {
  const StatementStatusPill({super.key, required this.settled});
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final color = settled ? Brand.green : Brand.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.094),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(settled ? 'Settled' : 'Issued',
          style: tw(FontWeight.w800, 11, color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
                const BoxDecoration(color: Brand.fill, shape: BoxShape.circle),
            child: const Center(child: Ico('receipt', size: 28, color: Brand.sub)),
          ),
          const SizedBox(height: 14),
          const McTitle('No statements yet', size: 18, align: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'Your first statement appears the Monday after your first completed week.',
            textAlign: TextAlign.center,
            style: tw(FontWeight.w600, 13.5, Brand.sub),
          ),
        ],
      ),
    );
  }
}

/// Load failure with a retry — shared with the detail screen.
class StatementErrorState extends StatelessWidget {
  const StatementErrorState(
      {super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McErrorBanner(message),
        const SizedBox(height: 12),
        McGhostButton('Try again', onTap: onRetry),
      ],
    );
  }
}

/// Signed money coloured by direction; zero stays plain ink.
class SignedAmount extends StatelessWidget {
  const SignedAmount(this.pence, {super.key, this.size = 14});
  final int pence;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = netDirection(pence);
    return Text(
      formatSignedGbp(pence),
      style: tw(FontWeight.w900, size,
          d == NetDirection.nothingDue ? Brand.ink : netColor(d)),
    );
  }
}
