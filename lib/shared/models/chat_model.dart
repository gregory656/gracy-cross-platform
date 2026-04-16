import 'message_model.dart';

class ChatModel {
  const ChatModel({
    required this.id,
    required this.participantId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.roomHash,
    this.isOfficial = false,
    this.gracyId,
    this.isOnline = false,
    this.lastMessageStatus = MessageStatus.sent,
    this.isLastMessageMine = true,
  });

  final String id;
  final String participantId;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final String? roomHash;
  final bool isOfficial;
  final String? gracyId;
  final bool isOnline;
  final MessageStatus lastMessageStatus;
  final bool isLastMessageMine;

  ChatModel copyWith({
    String? id,
    String? participantId,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? roomHash,
    bool? isOfficial,
    String? gracyId,
    bool? isOnline,
    MessageStatus? lastMessageStatus,
    bool? isLastMessageMine,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      roomHash: roomHash ?? this.roomHash,
      isOfficial: isOfficial ?? this.isOfficial,
      gracyId: gracyId ?? this.gracyId,
      isOnline: isOnline ?? this.isOnline,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      isLastMessageMine: isLastMessageMine ?? this.isLastMessageMine,
    );
  }
}
