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

  /// Who sent this message: `'rider'` or `'driver'`.
  final String senderType;
  final String senderId;
  final String content;
  final DateTime sentAtUtc;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'].toString(),
        tripId: j['tripId'].toString(),
        senderType: j['senderType'] as String,
        senderId: j['senderId'].toString(),
        content: j['content'] as String,
        sentAtUtc: DateTime.parse(j['sentAtUtc'] as String),
      );
}
