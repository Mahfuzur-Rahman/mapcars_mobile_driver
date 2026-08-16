import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../providers/trip_realtime_controller.dart';
import '../services/trip_service.dart';
import 'widgets/live_route_map.dart';

/// At the kerb: confirm the rider's meet-up PIN, then start the trip.
class ArrivedScreen extends ConsumerStatefulWidget {
  const ArrivedScreen({super.key, required this.trip});

  /// The accepted trip — always a real one, supplied or resolved by `TripGate`.
  final Trip trip;

  @override
  ConsumerState<ArrivedScreen> createState() => _ArrivedScreenState();
}

class _ArrivedScreenState extends ConsumerState<ArrivedScreen> {
  bool _busy = false;
  final _entered = <String>[];
  bool _pinError = false;

  String? get _expectedPin => widget.trip.pin;

  /// A trip booked before PINs existed has none — don't strand the driver
  /// behind a check there's no answer to.
  bool get _pinRequired => (_expectedPin?.length ?? 0) == 4;

  bool get _pinSatisfied =>
      !_pinRequired || _entered.join() == _expectedPin;

  void _tapDigit(String d) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered.add(d);
      _pinError = false;
    });
    if (_entered.length == 4 && !_pinSatisfied) {
      setState(() => _pinError = true);
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered.removeLast();
      _pinError = false;
    });
  }

  Future<void> _startTrip() async {
    if (_busy) return;
    final trip = widget.trip;
    if (!_pinSatisfied) {
      setState(() => _pinError = true);
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await ref.read(tripServiceProvider).start(trip.id);
      if (!mounted) return;
      context.go('/driving', extra: updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't start the trip. Please try again."),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final riderName = trip.rider?.name ?? 'Your rider';
    final rating = trip.rider?.rating;

    ref.listen<TripRealtimeState>(tripRealtimeProvider, (prev, next) {
      if (next.cancelledTrip?.id == trip.id) {
        showTripCancelledDialog(context, ref, next.cancelledTrip!);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            // Already at the pickup, so there's no route left to draw — the map
            // is here to confirm the driver is at the right spot.
            child: LiveRouteMap(
              destination: LatLng(trip.pickupLat, trip.pickupLng),
              destinationLabel: trip.pickupAddress,
              isPickup: true,
            ),
          ),
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: McFloatingNav(
              showHome: false,
              onBack: () => backOr(context, '/nav-pickup'),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const McAvatar(size: 52, color: Brand.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(riderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tw(FontWeight.w900, 17, Brand.ink)),
                              if (rating != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Ico('starF', size: 14, color: Brand.star),
                                    const SizedBox(width: 4),
                                    Text(rating.toStringAsFixed(1),
                                        style: tw(FontWeight.w800, 13, Brand.sub)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const _SquareButton(icon: 'phone'),
                        const SizedBox(width: 8),
                        _SquareButton(
                            icon: 'msg', onTap: () => context.push('/chat', extra: trip)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_pinRequired)
                      _PinPad(
                        entered: _entered,
                        error: _pinError,
                        onDigit: _tapDigit,
                        onBackspace: _backspace,
                      )
                    else
                      McCard(
                        padding: 14,
                        child: Row(
                          children: [
                            const Ico('shield', size: 18, color: Brand.sub),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('No PIN on this trip — confirm the '
                                  'rider by name before setting off.',
                                  style: tw(FontWeight.w700, 12.5, Brand.sub)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    McButton(
                      _busy ? 'Starting…' : 'Start trip',
                      icon: 'nav',
                      kind: BtnKind.green,
                      onTap: (_busy || !_pinSatisfied) ? null : _startTrip,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, this.onTap});
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Brand.fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Ico(icon, size: 20, color: Brand.ink)),
        ),
      );
}

/// The rider reads their 4-digit code out; the driver keys it in here. This is
/// what proves the person getting in is the person who booked.
class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.entered,
    required this.error,
    required this.onDigit,
    required this.onBackspace,
  });

  final List<String> entered;
  final bool error;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return McCard(
      padding: 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error ? "That PIN doesn't match" : "Confirm rider's PIN",
            style: tw(FontWeight.w700, 12.5, error ? Brand.errorText : Brand.sub),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _PinBox(
                  i < entered.length ? entered[i] : '',
                  error: error,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '<'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: key.isEmpty
                          ? const SizedBox(height: 44)
                          : _Key(
                              label: key,
                              onTap: key == '<'
                                  ? onBackspace
                                  : () => onDigit(key),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Brand.fill,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: label == '<'
                ? const Ico('back', size: 18, color: Brand.ink)
                : Text(label, style: tw(FontWeight.w900, 18, Brand.ink)),
          ),
        ),
      );
}

class _PinBox extends StatelessWidget {
  const _PinBox(this.digit, {this.error = false});
  final String digit;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 50,
        decoration: BoxDecoration(
          color: Brand.fill,
          borderRadius: BorderRadius.circular(12),
          border: error ? Border.all(color: Brand.errorText, width: 1.5) : null,
        ),
        child: Center(
          child: Text(digit, style: tw(FontWeight.w900, 22, Brand.ink)),
        ),
      );
}
