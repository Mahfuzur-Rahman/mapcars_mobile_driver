/// A single chat message in a trip conversation. Mirrors the API's
/// `MessageResponse` (`Mapcars.Application/Messages/Dtos/MessageDtos.cs`).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.tripId,
    required this.senderType,
    required this.senderId,
    required this.content,
    required this.sentAtUtc,
  });

  final String id;
  final String tripId;

  /// Who sent this message: `'customer'` or `'driver'`.
  final String senderType;
  final String senderId;
  final String content;
  final DateTime sentAtUtc;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'].toString(),
        tripId: j['tripId'].toString(),
        senderType: _canonicalSender(j['senderType'] as String),
        senderId: j['senderId'].toString(),
        content: j['content'] as String,
        sentAtUtc: DateTime.parse(j['sentAtUtc'] as String),
      );
}

/// Folds the passenger's sender type onto one spelling.
///
/// The API sends 'rider' until the Rider -> Customer rename cutover and
/// 'customer' after it. Normalising here, at the single parse boundary, means
/// nothing downstream has to know the rename ever happened - in particular
/// [unreadAfter], where a missed match would silently stop the unread badge
/// counting rather than throw.
String _canonicalSender(String raw) =>
    raw.toLowerCase() == 'rider' ? 'customer' : raw;

/// The unread count once [message] arrives.
///
/// Extracted so the rule is stated in one place and can be tested: your own
/// messages are never unread, and nothing is unread while you are looking at
/// the conversation. [otherParty] is `'driver'` in the customer app and `'customer'`
/// in the driver app.
int unreadAfter({
  required int current,
  required ChatMessage message,
  required String otherParty,
  required bool chatOpen,
}) =>
    message.senderType == otherParty && !chatOpen ? current + 1 : current;
