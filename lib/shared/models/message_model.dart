class MessageModel {
  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.isMe,
    this.senderName = 'Unknown',
    this.senderUsername,
    this.isOfficial = false,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isMe;
  final String senderName;
  final String? senderUsername;
  final bool isOfficial;

  factory MessageModel.fromDatabase({
    required Map<String, dynamic> row,
    required String currentUserId,
    required String senderName,
    required String? senderUsername,
    required bool isOfficial,
  }) {
    return MessageModel(
      id: row['id']?.toString() ?? '',
      chatId: row['room_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      text: row['content']?.toString() ?? '',
      sentAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      isMe: row['sender_id']?.toString() == currentUserId,
      senderName: senderName,
      senderUsername: senderUsername,
      isOfficial: isOfficial,
    );
  }
}
