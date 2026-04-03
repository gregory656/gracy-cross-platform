class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.receiverId,
    required this.senderId,
    required this.type,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String receiverId;
  final String senderId;
  final String type;
  final String? content;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as int,
      receiverId: map['receiver_id'] as String,
      senderId: map['sender_id'] as String,
      type: map['type'] as String,
      content: map['content'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
