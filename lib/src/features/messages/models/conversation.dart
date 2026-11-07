/// One row of the Messages list — one conversation per trip. Mirrors the API's
/// `ConversationResponse` (`Mapcars.Application/Messages/Dtos/MessageDtos.cs`).
class Conversation {
  const Conversation({
    required this.tripId,
    required this.counterpartName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.tripStatus,
    required this.tripDateUtc,
    required this.lastMessage,
    required this.unreadCount,
    required this.canSend,
  });

  final String tripId;
  final String counterpartName;
  final String pickupAddress;
  final String dropoffAddress;

  /// The API's TripStatus name, e.g. `InProgress`, `Completed`.
  final String tripStatus;
  final DateTime tripDateUtc;

  /// Null for a trip with no messages yet (opened from an active trip).
  final ConversationPreview? lastMessage;
  final int unreadCount;

  /// False once the chat has closed (24 h after completion, or cancelled).
  final bool canSend;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final last = j['lastMessage'];
    return Conversation(
      tripId: j['tripId'].toString(),
      counterpartName: (j['counterpartName'] as String?) ?? '',
      pickupAddress: (j['pickupAddress'] as String?) ?? '',
      dropoffAddress: (j['dropoffAddress'] as String?) ?? '',
      tripStatus: (j['tripStatus'] as String?) ?? '',
      tripDateUtc: DateTime.parse(j['tripDateUtc'] as String).toUtc(),
      lastMessage: last is Map
          ? ConversationPreview.fromJson(Map<String, dynamic>.from(last))
          : null,
      unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
      canSend: j['canSend'] == true,
    );
  }

  /// "Heathrow T5 → Soho Square": the first comma-part of each address.
  String get routeLabel =>
      '${_short(pickupAddress)} → ${_short(dropoffAddress)}';

  static String _short(String address) {
    final first = address.split(',').first.trim();
    return first.isEmpty ? address : first;
  }
}

class ConversationPreview {
  const ConversationPreview({
    required this.content,
    required this.senderType,
    required this.sentAtUtc,
  });

  final String content;

  /// `'customer'` or `'driver'` (legacy `'rider'` folded onto `'customer'`).
  final String senderType;
  final DateTime sentAtUtc;

  factory ConversationPreview.fromJson(Map<String, dynamic> j) =>
      ConversationPreview(
        content: (j['content'] as String?) ?? '',
        senderType: _canonical((j['senderType'] as String?) ?? ''),
        sentAtUtc: DateTime.parse(j['sentAtUtc'] as String).toUtc(),
      );

  static String _canonical(String raw) =>
      raw.toLowerCase() == 'rider' ? 'customer' : raw.toLowerCase();
}

/// `GET /conversations/unread`: the badge total plus each trip's own count.
class UnreadSummary {
  const UnreadSummary({required this.total, required this.byTrip});

  final int total;
  final Map<String, int> byTrip;

  factory UnreadSummary.fromJson(Map<String, dynamic> j) {
    final trips = (j['trips'] as List?) ?? const [];
    return UnreadSummary(
      total: (j['total'] as num?)?.toInt() ?? 0,
      byTrip: {
        for (final t in trips.whereType<Map>())
          t['tripId'].toString(): (t['count'] as num?)?.toInt() ?? 0,
      },
    );
  }
}
