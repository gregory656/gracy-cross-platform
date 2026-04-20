import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/chat_model.dart';
import '../../../shared/models/chat_thread.dart';
import '../../../shared/models/local_first_data.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/social_providers.dart';
import '../../../shared/services/database_service.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    supabase: Supabase.instance.client,
    databaseService: DatabaseService.instance,
  );
});

final recentChatsProvider = StreamProvider<LocalFirstData<List<ChatModel>>>((
  ref,
) {
  final String? currentUserId = ref.watch(authNotifierProvider).userId;
  if (currentUserId == null) {
    return Stream<LocalFirstData<List<ChatModel>>>.value(
      const LocalFirstData<List<ChatModel>>(data: <ChatModel>[]),
    );
  }

  return ref.watch(chatRepositoryProvider).watchRecentChats(currentUserId);
});

final messagesProvider =
    StreamProvider.family<LocalFirstData<List<MessageModel>>, String>((
      ref,
      String roomId,
    ) {
  final String? currentUserId = ref.watch(authNotifierProvider).userId;
  if (currentUserId == null) {
    return Stream<LocalFirstData<List<MessageModel>>>.value(
      const LocalFirstData<List<MessageModel>>(data: <MessageModel>[]),
    );
  }

  return ref
      .watch(chatRepositoryProvider)
      .watchMessages(roomId: roomId, currentUserId: currentUserId);
});

final chatThreadProvider =
    FutureProvider.family<ChatThread?, ChatThreadRequest>((
      ref,
      ChatThreadRequest request,
    ) async {
      final String? currentUserId = ref.watch(authNotifierProvider).userId;
      if (currentUserId == null) {
        return null;
      }

      return ref
          .watch(chatRepositoryProvider)
          .resolveThread(
            currentUserId: currentUserId,
            roomId: request.roomId,
            userId: request.userId,
            receiverName: request.receiverName,
            receiverAvatar: request.receiverAvatar,
          );
    });

final startChatControllerProvider =
    AsyncNotifierProvider<StartChatController, void>(StartChatController.new);

class StartChatController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<ChatThread> startByCode(String gracyCode) async {
    final String? currentUserId = ref.read(authNotifierProvider).userId;
    if (currentUserId == null) {
      throw const ChatRepositoryException(
        'You need to complete onboarding first.',
      );
    }

    state = const AsyncLoading<void>();

    try {
      final ChatThread thread = await ref
          .read(chatRepositoryProvider)
          .findOrCreateRoomByCode(
            currentUserId: currentUserId,
            gracyId: gracyCode,
          );
      state = const AsyncData<void>(null);
      ref.invalidate(recentChatsProvider);
      
      // Atomic open
      ref.read(activeChatProvider.notifier).openChat(thread.roomId);
      
      return thread;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }
}

final activeChatProvider = NotifierProvider<ActiveChatNotifier, String?>(ActiveChatNotifier.new);

class ActiveChatNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void openChat(String? roomId) {
    if (roomId == null || state == roomId) return;

    // 1. Clear previous chat context if switching
    if (state != null && state != roomId) {
      // Invalidate messages for the previous room to ensure "blank slate"
      ref.invalidate(messagesProvider(state!));
    }

    // 2. Set active ID
    state = roomId;

    // 3. Mark as read in Supabase and locally
    final String? currentUserId = ref.read(authNotifierProvider).userId;
    if (currentUserId == null) return;

    // Trigger async mark read (Safe because it's an action, not during build)
    _performMarkRead(roomId, currentUserId);
  }

  Future<void> _performMarkRead(String roomId, String currentUserId) async {
    try {
      // First local update to UI
      ref.read(localReadChatsProvider.notifier).markRead(roomId);
    } catch (_) {}
  }

  void closeChat() {
    state = null;
  }
}
