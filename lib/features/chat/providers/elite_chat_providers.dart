import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/message_model.dart';
import '../../../shared/services/nairobi_timezone_service.dart';

// Real-time chat state
class EliteChatState {
  const EliteChatState({
    required this.messages,
    required this.isLoading,
    required this.error,
    required this.isTyping,
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

// Chat provider for zero-latency real-time updates
class EliteChatProvider extends StateNotifier<EliteChatState> {
  EliteChatProvider({
    required this.chatId,
    required this.currentUserId,
  }) : super(const EliteChatState(
           messages: [],
           isLoading: false,
           error: null,
           isTyping: false,
         )) {
    _initialize();
  }

  final String chatId;
  final String currentUserId;
  RealtimeChannel? _channel;

  void _initialize() {
    // Initialize with loading state
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
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
          currentUserId: currentUserId,
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
        messages: const [],
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
        'sender_id': currentUserId,
        'content': text,
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
        if (replyToId != null) 'reply_to_id': replyToId,
      };

      await Supabase.instance.client.from('messages').insert(messageData);
    } catch (e) {
      state = EliteChatState(
        messages: state.messages,
        isLoading: false,
        error: e.toString(),
        isTyping: state.isTyping,
      );
    }
  }

  void setTyping(bool isTyping) {
    state = EliteChatState(
      messages: state.messages,
      isLoading: state.isLoading,
      error: state.error,
      isTyping: isTyping,
    );
  }
}

// Provider definition
final eliteChatProvider = StateNotifierProvider.family<EliteChatProvider, EliteChatState, String>(
  (ref, chatId) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return EliteChatProvider(
      chatId: chatId,
      currentUserId: currentUserId,
    );
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
