import 'package:flutter/material.dart';

enum MessageStatus { sent, delivered, read }

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
    this.status = MessageStatus.sent,
    this.deliveredAt,
    this.readAt,
    this.replyToId,
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
  final MessageStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? replyToId;

  factory MessageModel.fromDatabase({
    required Map<String, dynamic> row,
    required String currentUserId,
    required String senderName,
    required String? senderUsername,
    required bool isOfficial,
  }) {
    final String statusStr = row['status']?.toString() ?? 'sent';
    MessageStatus status = MessageStatus.sent;
    switch (statusStr) {
      case 'delivered':
        status = MessageStatus.delivered;
        break;
      case 'read':
        status = MessageStatus.read;
        break;
      case 'sent':
      default:
        status = MessageStatus.sent;
        break;
    }

    return MessageModel(
      id: row['id']?.toString() ?? '',
      chatId: row['room_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      text: row['content']?.toString() ?? '',
      sentAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isMe: row['sender_id']?.toString() == currentUserId,
      senderName: senderName,
      senderUsername: senderUsername,
      isOfficial: isOfficial,
      status: status,
      deliveredAt: row['delivered_at'] != null
          ? DateTime.tryParse(row['delivered_at'].toString())
          : null,
      readAt: row['read_at'] != null
          ? DateTime.tryParse(row['read_at'].toString())
          : null,
      replyToId: row['reply_to_id']?.toString(),
    );
  }

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
    DateTime? deliveredAt,
    DateTime? readAt,
    String? replyToId,
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
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      replyToId: replyToId ?? this.replyToId,
    );
  }

  // Get status tick icons for display
  List<IconData> get statusTicks {
    if (!isMe) return [];

    switch (status) {
      case MessageStatus.sent:
        return [Icons.done];
      case MessageStatus.delivered:
        return [Icons.done_all];
      case MessageStatus.read:
        return [Icons.done_all];
    }
  }

  // Get status color
  String get statusColorHex {
    if (!isMe) return '';

    switch (status) {
      case MessageStatus.sent:
        return '#8E8E93'; // Gray
      case MessageStatus.delivered:
        return '#8E8E93'; // Gray
      case MessageStatus.read:
        return '#007AFF'; // Electric Blue
    }
  }
}
