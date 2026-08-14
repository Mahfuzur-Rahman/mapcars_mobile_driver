import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../auth/services/driver_auth_service.dart';
import '../../drive/services/trip_service.dart';
import '../services/vehicle_service.dart';

class ProfileVehicleScreen extends ConsumerStatefulWidget {
  const ProfileVehicleScreen({super.key});

  @override
  ConsumerState<ProfileVehicleScreen> createState() => _ProfileVehicleScreenState();
}

class _ProfileVehicleScreenState extends ConsumerState<ProfileVehicleScreen> {
  DriverProfile? _profile;
  Vehicle? _vehicle;
  int? _completedTrips;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ref.read(authNotifierProvider.notifier).loadProfile(),
      ref.read(vehicleServiceProvider).getMine().catchError((_) => null),
      ref.read(tripServiceProvider).mine().catchError((_) => <Trip>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as DriverProfile?;
      _vehicle = results[1] as Vehicle?;
      _completedTrips = (results[2] as List<Trip>)
          .where((t) => t.status == TripStatus.completed)
          .length;
      _loading = false;
    });
  }

  Future<void> _editVehicle() async {
    final saved = await context.push<Vehicle>('/profile/vehicle', extra: _vehicle);
    if (saved != null && mounted) setState(() => _vehicle = saved);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final token = ref.watch(authTokenProvider);
    final profile = _profile;
    final rating = profile?.averageRating;
    final since = profile?.createdAtUtc?.year;

    final stats = <(String, String)>[
      (_loading ? '—' : '${_completedTrips ?? 0}', 'Trips'),
      (rating != null ? rating.toStringAsFixed(2) : '—', 'Rating'),
      ('${profile?.ratingCount ?? 0}', 'Rated'),
    ];

    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _DriverTabBar(active: 'account'),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McNavHeader(title: 'Profile', fallback: '/home'),
              const SizedBox(height: 18),
              // Profile row
              Row(
                children: [
                  if (profile != null && profile.hasProfilePicture && token != null)
                    ClipOval(
                      child: Image.network(
                        ref.read(driverAuthServiceProvider).profilePictureUrl(Env.apiBaseUrl),
                        headers: {'Authorization': 'Bearer $token'},
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const McAvatar(size: 68, color: Brand.blue),
                      ),
                    )
                  else
                    const McAvatar(size: 68, color: Brand.blue),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.fullName ?? 'Add your name', style: tw(FontWeight.w900, 19)),
                        Row(
                          children: [
                            const Ico('starF', size: 15, color: Brand.star),
                            const SizedBox(width: 5),
                            Text(
                              [
                                if (rating != null) rating.toStringAsFixed(2) else 'No rating yet',
                                if (since != null) 'Since $since',
                              ].join(' · '),
                              style: tw(FontWeight.w700, 13.5, Brand.sub),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile/edit'),
                    child: const Ico('edit', size: 20, color: Brand.sub),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stat cards
              Row(
                children: [
                  for (int i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: McCard(
                        padding: 12,
                        child: Column(
                          children: [
                            Text(stats[i].$1, style: tw(FontWeight.w900, 18)),
                            Text(stats[i].$2, style: tw(FontWeight.w700, 11, Brand.sub)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Text('VEHICLE', style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
              const SizedBox(height: 10),
              if (_loading)
                const McCard(
                  padding: 20,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
                )
              else if (_vehicle == null)
                McCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "You haven't added a vehicle yet.",
                        style: tw(FontWeight.w700, 14, Brand.sub),
                      ),
                      const SizedBox(height: 12),
                      McButton('Add your vehicle', icon: 'car', onTap: _editVehicle),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _editVehicle,
                  child: McCard(
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Brand.fill,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Center(child: Ico('car', size: 28, color: Brand.blue)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_vehicle!.make} ${_vehicle!.model}',
                                  style: tw(FontWeight.w900, 16)),
                              Text('${_vehicle!.colour} · ${_vehicle!.year}',
                                  style: tw(FontWeight.w600, 12.5, Brand.sub)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Brand.fill,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_vehicle!.registrationNumber,
                              style: tw(FontWeight.w900, 14, Brand.ink, 0.5)),
                        ),
                        const SizedBox(width: 8),
                        const Ico('chevR', size: 16, color: Brand.sub),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Text('DOCUMENTS', style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.push('/documents'),
                child: McCard(
                  child: Row(
                    children: [
                      const Ico('doc', size: 20, color: Brand.sub),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('View your PHV licence, insurance & MOT',
                            style: tw(FontWeight.w700, 13.5)),
                      ),
                      const Ico('chevR', size: 16, color: Brand.sub),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverTabBar extends StatelessWidget {
  const _DriverTabBar({required this.active});
  final String active;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String, String)>[
      ('wheel', 'Drive', 'drive', '/home'),
      ('chart', 'Earnings', 'earn', '/earnings'),
      ('user', 'Account', 'account', '/profile'),
    ];
    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: Brand.paper,
        border: Border(top: BorderSide(color: Brand.fill)),
      ),
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          for (final (ic, label, key, route) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go(route),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Ico(ic, size: 24, color: key == active ? Brand.blue : Brand.faint),
                    const SizedBox(height: 3),
                    Text(label,
                        style: tw(FontWeight.w800, 11,
                            key == active ? Brand.blue : Brand.faint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
