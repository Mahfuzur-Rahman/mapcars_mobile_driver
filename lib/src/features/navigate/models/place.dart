/// A geographic point with a human label — a search result / destination.
class Place {
  const Place({
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String label; // 'Tower Bridge'
  final String address; // 'London SE1 2UP'
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        label: (j['label'] ?? j['address'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
      );
}
