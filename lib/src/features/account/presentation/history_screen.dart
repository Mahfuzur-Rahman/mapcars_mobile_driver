import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/mc.dart';
import '../../drive/services/trip_service.dart';
import '../providers/driver_trips_provider.dart';

class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(driverTripsProvider);

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(driverTripsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: McNavHeader(title: 'Trip history', fallback: '/home'),
                ),
                const SizedBox(height: 12),
                tripsAsync.when(
                  data: (trips) => _buildList(trips),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 40),
                    child: Text("Couldn't load your trip history.",
                        style: tw(FontWeight.w700, 14, Brand.sub)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Trip> trips) {
    final completed = trips.where((t) => t.status == TripStatus.completed).toList();
    if (completed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 40),
        child: Text('No completed trips yet.', style: tw(FontWeight.w700, 14, Brand.sub)),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < completed.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          McCard(
            padding: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Brand.fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Ico('nav', size: 22, color: Brand.sub)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(completed[i].pickupAddress,
                                style: tw(FontWeight.w900, 15)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatGbp(((completed[i].driverEarnings ?? 0) * 100).round()),
                            style: tw(FontWeight.w900, 15, Brand.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              formatRelativeDateTime(
                                  completed[i].completedAtUtc ?? completed[i].createdAtUtc),
                              style: tw(FontWeight.w600, 12.5, Brand.sub),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
