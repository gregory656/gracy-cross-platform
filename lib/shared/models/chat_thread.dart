import '../models/user_model.dart';

class ChatThreadRequest {
  const ChatThreadRequest({
    this.roomId,
    this.userId,
    required this.receiverId,
    this.receiverName,
    this.receiverAvatar,
  });

  final String? roomId;
  final String? userId;
  final String receiverId;
  final String? receiverName;
  final String? receiverAvatar;

  @override
  bool operator ==(Object other) {
    return other is ChatThreadRequest &&
        other.roomId == roomId &&
        other.userId == userId &&
        other.receiverId == receiverId &&
        other.receiverName == receiverName &&
        other.receiverAvatar == receiverAvatar;
  }

  @override
  int get hashCode => Object.hash(
        roomId,
        userId,
        receiverId,
        receiverName,
        receiverAvatar,
      );
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

