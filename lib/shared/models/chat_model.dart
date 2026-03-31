class ChatModel {
  const ChatModel({
    required this.id,
    required this.participantId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String id;
  final String participantId;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
}

