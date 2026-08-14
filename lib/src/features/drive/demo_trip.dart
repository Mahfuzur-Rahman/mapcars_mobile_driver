import 'services/trip_service.dart';

/// A fake trip used only to preview the trip-flow screens from the dev
/// "Screens" menu / walkthrough drawer, so those previews render the real
/// `LiveRouteMap`/`RequestCard` instead of falling back to static art. Never
/// used in the live flow — production screens always get a real [Trip] from
/// the API. Coordinates match the customer app's own demo route
/// (`ride_flow_notifier.dart`'s `fallbackPickup`/`fallbackDropoff`).
final demoTrip = Trip(
  id: 'demo-trip',
  pickupAddress: '40 Canary Wharf, London E14',
  pickupLat: 51.5054,
  pickupLng: -0.0235,
  dropoffAddress: 'Tower Bridge, SE1',
  dropoffLat: 51.5055,
  dropoffLng: -0.0754,
  status: TripStatus.driverAssigned,
  fareAmount: 11.50,
  distanceMiles: 4.3,
  durationMinutes: 18,
  tier: 'economy',
  paymentMethod: 'Cash',
  rider: const TripRider(name: 'Sarah M.', rating: 4.8),
  pin: '1234',
  createdAtUtc: DateTime.utc(2026, 1, 1),
);
