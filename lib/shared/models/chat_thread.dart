import '../models/user_model.dart';

class ChatThreadRequest {
  final String? roomId;
  final String? userId;
  final String receiverId;
  final String? receiverName;
  final String? receiverAvatar;

  ChatThreadRequest({
    this.roomId,
    this.userId,
    required this.receiverId,
    this.receiverName,
    this.receiverAvatar,
  });
}

class ChatThread {
  final String id;
  final String participantId;
  final String roomId;
  final UserModel participant;

  const ChatThread({
    required this.id,
    required this.participantId,
    required this.roomId,
    required this.participant,
  });
}

