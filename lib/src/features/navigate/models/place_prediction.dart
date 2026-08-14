/// A single address suggestion from Google Places Autocomplete. Holds only what
/// the list needs; the exact coordinates are fetched later via place details.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText; // "Tower Bridge"
  final String secondaryText; // "London SE1 2UP, UK"

  factory PlacePrediction.fromJson(Map<String, dynamic> j) {
    final s = (j['structured_formatting'] as Map<String, dynamic>?) ?? const {};
    return PlacePrediction(
      placeId: j['place_id'] as String? ?? '',
      primaryText:
          (s['main_text'] as String?) ?? (j['description'] as String? ?? ''),
      secondaryText: (s['secondary_text'] as String?) ?? '',
    );
  }
}
