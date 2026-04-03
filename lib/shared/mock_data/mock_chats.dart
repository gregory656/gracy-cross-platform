import '../models/chat_model.dart';

// REPLACE WITH API DATA SOURCE
final List<ChatModel> mockChats = <ChatModel>[
  ChatModel(
    id: 'c1',
    participantId: 'u2',
    lastMessage: 'Let me know when you want to review the onboarding flow.',
    lastMessageAt: DateTime(2026, 3, 31, 17, 20),
    unreadCount: 2,
  ),
  ChatModel(
    id: 'c2',
    participantId: 'u3',
    lastMessage: 'I shared the slides for the design critique.',
    lastMessageAt: DateTime(2026, 3, 31, 16, 45),
    unreadCount: 0,
  ),
  ChatModel(
    id: 'c3',
    participantId: 'u4',
    lastMessage: 'Happy to introduce you to the internship cohort.',
    lastMessageAt: DateTime(2026, 3, 31, 14, 10),
    unreadCount: 1,
  ),
  ChatModel(
    id: 'c4',
    participantId: 'u5',
    lastMessage: 'The dark gradient version looks much stronger.',
    lastMessageAt: DateTime(2026, 3, 31, 12, 30),
    unreadCount: 0,
  ),
];
