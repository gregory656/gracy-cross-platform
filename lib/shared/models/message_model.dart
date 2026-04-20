import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isMe;
  final String senderName;
  final String? senderUsername;
  final bool isOfficial;
  final MessageStatus status;
  final bool isPending;
  final String? replyToId;
  final int statusTicks;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.isMe,
    required this.senderName,
    this.senderUsername,
    this.isOfficial = false,
    this.status = MessageStatus.sent,
    this.isPending = false,
    this.replyToId,
    this.statusTicks = 0,
  });

  @override
  List<Object?> get props => [id, chatId, senderId, text, sentAt, isMe, senderName, senderUsername, isOfficial, status, isPending, replyToId, statusTicks];

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? sentAt,
    bool? isMe,
    String? senderName,
    String? senderUsername,
    bool? isOfficial,
    MessageStatus? status,
    bool? isPending,
    String? replyToId,
    int? statusTicks,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isMe: isMe ?? this.isMe,
      senderName: senderName ?? this.senderName,
      senderUsername: senderUsername ?? this.senderUsername,
      isOfficial: isOfficial ?? this.isOfficial,
      status: status ?? this.status,
      isPending: isPending ?? this.isPending,
      replyToId: replyToId ?? this.replyToId,
      statusTicks: statusTicks ?? this.statusTicks,
    );
  }
}

enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
}
