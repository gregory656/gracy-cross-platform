import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/message_model.dart';
import '../../../shared/services/nairobi_timezone_service.dart';

// Real-time chat state
class EliteChatState {
  const EliteChatState({
    required this.messages,
    this.isLoading = false,
    this.error,
    this.isTyping = false,
  });

  final List<MessageModel> messages;
  final bool isLoading;
  final String? error;
  final bool isTyping;

  EliteChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    String? error,
    bool? isTyping,
  }) {
    return EliteChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

// Chat notifier for zero-latency real-time updates
class EliteChatNotifier extends StateNotifier<EliteChatState> {
  EliteChatNotifier({
    required this.chatId,
    required String currentUserId,
  }) : _currentUserId = currentUserId,
       super(const EliteChatState(messages: []));

  final String chatId;
  final String _currentUserId;

  Future<void> loadMessages() async {
    try {
      state = state.copyWith(isLoading: true);

      final response = await Supabase.instance.client
          .from('messages')
          .select('''
            *,
            profiles!messages_sender_id_fkey (
              full_name,
              username,
              is_official
            )
          ''')
          .eq('room_id', chatId)
          .order('created_at', ascending: true);

      final messages = response.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>? ?? {};
        return MessageModel.fromDatabase(
          row: row,
          currentUserId: _currentUserId,
          senderName: profile['full_name'] ?? 'Unknown',
          senderUsername: profile['username'],
          isOfficial: profile['is_official'] ?? false,
        );
      }).toList();

      state = EliteChatState(
        messages: messages,
        isLoading: false,
        error: null,
        isTyping: false,
      );
    } catch (e) {
      state = EliteChatState(
        messages: [],
        isLoading: false,
        error: e.toString(),
        isTyping: false,
      );
    }
  }

  Future<void> sendMessage(String text, {String? replyToId}) async {
    try {
      final messageData = {
        'room_id': chatId,
        'sender_id': _currentUserId,
        'content': text,
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
        ...?replyToId == null ? null : {'reply_to_id': replyToId},
      };

      await Supabase.instance.client.from('messages').insert(messageData);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void setTyping(bool isTyping) {
    state = state.copyWith(isTyping: isTyping);
  }
}

// Provider definition
final eliteChatProvider = StateNotifierProvider.autoDispose.family<EliteChatNotifier, EliteChatState, String>(
  (ref, chatId) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return EliteChatNotifier(chatId: chatId, currentUserId: currentUserId);
  },
);

// Provider for current user ID
final currentUserIdProvider = Provider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id ?? '';
});

// Provider for Nairobi timezone service
final nairobiTimezoneProvider = Provider<NairobiTimezoneService>((ref) {
  return NairobiTimezoneService.instance;
});
