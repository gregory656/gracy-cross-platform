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
}
