import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/mc.dart';
import '../providers/fare_chart_provider.dart';
import '../services/rating_service.dart';
import '../services/trip_service.dart';

class TripCompleteScreen extends ConsumerStatefulWidget {
  const TripCompleteScreen({super.key, this.trip});

  /// The just-completed trip, when the caller has one — null falls back to
  /// the static walkthrough figures below (dev screen-stepper).
  final Trip? trip;

  // Demo trip fare until a real completed trip is passed in. The commission %
  // below is always live — pulled from the fare chart — so the walkthrough
  // earnings track the current platform config.
  static const _farePence = 1150;

  @override
  ConsumerState<TripCompleteScreen> createState() => _TripCompleteScreenState();
}

class _TripCompleteScreenState extends ConsumerState<TripCompleteScreen> {
  int _rating = 0;
  bool _submitting = false;
  bool _submitted = false;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0 || _submitting || _submitted) return;

    final tripId = widget.trip?.id;
    if (tripId == null) {
      // No real trip wired in (dev screen-stepper walkthrough) — nothing to
      // rate against on the API, so just acknowledge locally.
      setState(() => _submitted = true);
      return;
    }

    setState(() => _submitting = true);
    final comment = _commentCtrl.text.trim();
    try {
      await ref.read(ratingServiceProvider).rateTrip(
            tripId,
            score: _rating,
            comment: comment.isEmpty ? null : comment,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't submit your rating. Please try again."),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isCash = trip?.isCash ?? false;
    final feePercent =
        ref.watch(fareChartProvider).asData?.value.driverFeePercent ?? 15.0;

    final farePence = trip?.fareAmount != null
        ? (trip!.fareAmount! * 100).round()
        : TripCompleteScreen._farePence;
    final feePence = trip?.platformFeeAmount != null
        ? (trip!.platformFeeAmount! * 100).round()
        : (farePence * feePercent / 100).round();
    // The API's driverEarnings is the base take-home (fare − fee); the tip is a
    // separate field paid 100% to the driver, so add it back for the total.
    final baseEarningsPence = trip?.driverEarnings != null
        ? (trip!.driverEarnings! * 100).round()
        : farePence - feePence;
    final tipPence = trip != null ? (trip.tipAmount * 100).round() : 0;
    final earningsPence = baseEarningsPence + tipPence;
    final feeLabel = feePercent % 1 == 0
        ? feePercent.toStringAsFixed(0)
        : feePercent.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trip's over — nothing to go back to, but Home and the menu
              // stay reachable.
              const McNavHeader(showBack: false),
              const SizedBox(height: 18),
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Brand.gradGreen,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x5F31A424),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Ico('check', size: 34, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const McTitle('Trip complete', size: 22),
                  const SizedBox(height: 6),
                  Text('You earned',
                      style: tw(FontWeight.w700, 13.5, Brand.sub)),
                  const SizedBox(height: 4),
                  Text(formatGbp(earningsPence),
                      style: tw(FontWeight.w900, 40, Brand.ink, -1)),
                ],
              ),
              const SizedBox(height: 16),
              McCard(
                padding: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BreakdownRow('Trip fare', formatGbp(farePence)),
                    _BreakdownRow('MAP CARS fee ($feeLabel%)', '−${formatGbp(feePence)}'),
                    _BreakdownRow('Tip', formatGbp(tipPence)),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Brand.fill,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your earnings',
                            style: tw(FontWeight.w900, 15, Brand.ink)),
                        Text(formatGbp(earningsPence),
                            style: tw(FontWeight.w900, 18, Brand.green)),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Brand.fill, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Ico(isCash ? 'cash' : 'card', size: 18, color: Brand.sub),
                          const SizedBox(width: 8),
                          Text(
                              isCash
                                  ? 'Collected ${formatGbp(((trip?.cashDue ?? 0) * 100).round())} in cash'
                                  : 'Paid by card · added to balance',
                              style: tw(FontWeight.w700, 13, Brand.sub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              McCard(
                padding: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(trip != null ? 'Rate your rider' : 'Rate Sarah',
                        style: tw(FontWeight.w900, 14, Brand.ink)),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: _submitted
                                ? null
                                : () => setState(() => _rating = star),
                            child: Ico(
                              star <= _rating ? 'starF' : 'star',
                              size: 30,
                              color: star <= _rating ? Brand.star : Brand.line,
                            ),
                          ),
                        );
                      }),
                    ),
                    if (!_submitted) ...[
                      const SizedBox(height: 12),
                      McField(
                        icon: 'edit',
                        placeholder: 'Leave a comment (optional)',
                        controller: _commentCtrl,
                        editable: true,
                      ),
                      const SizedBox(height: 12),
                      McGhostButton(
                        _submitting ? 'Submitting…' : 'Submit rating',
                        height: 46,
                        onTap:
                            (_rating == 0 || _submitting) ? null : _submitRating,
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Ico('check', size: 16, color: Brand.green),
                          const SizedBox(width: 6),
                          Text(trip != null ? 'Thanks for rating your rider!' : 'Thanks for rating Sarah!',
                              style: tw(FontWeight.w800, 13, Brand.green)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              McButton(
                'Back online',
                icon: 'nav',
                kind: BtnKind.green,
                onTap: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: tw(FontWeight.w600, 14, Brand.sub)),
            Text(value, style: tw(FontWeight.w700, 14, Brand.ink)),
          ],
        ),
      );
}
