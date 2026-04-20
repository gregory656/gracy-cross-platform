class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool isSent;
  final bool isDelivered;
  final bool isRead;

  const Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.isSent = false,
    this.isDelivered = false,
    this.isRead = false,
  });
}

