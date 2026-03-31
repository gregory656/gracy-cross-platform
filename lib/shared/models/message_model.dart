class MessageModel {
  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.isMe,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isMe;
}

