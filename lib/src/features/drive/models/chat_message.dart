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

  /// Builds a message from an FCM `messageReceived` data payload (string values).
  ///
  /// Null when the payload lacks the message — a push from an API older than the
  /// inbox — so the caller falls back to re-reading the unread count.
  static ChatMessage? fromPushData(Map<String, dynamic> data) {
    String? read(String key) {
      final v = data[key]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    final id = read('messageId');
    final tripId = read('tripId');
    final sender = read('senderType');
    final content = read('content');
    final sent = DateTime.tryParse(read('sentAtUtc') ?? '');
    if (id == null ||
        tripId == null ||
        sender == null ||
        content == null ||
        sent == null) {
      return null;
    }
    return ChatMessage(
      id: id,
      tripId: tripId,
      senderType: _canonicalSender(sender),
      senderId: read('senderId') ?? '',
      content: content,
      sentAtUtc: sent.toUtc(),
    );
  }
}

/// Folds the passenger's sender type onto one spelling.
///
/// The API sends 'rider' until the Rider -> Customer rename cutover and
/// 'customer' after it. Normalising here, at the single parse boundary, means
/// nothing downstream has to know the rename ever happened - in particular
/// the unread rule (`classifyIncoming`), where a missed match would silently
/// stop the unread badge counting rather than throw.
String _canonicalSender(String raw) =>
    raw.toLowerCase() == 'rider' ? 'customer' : raw;
