import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/chat_model.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/database_service.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    Supabase.instance.client,
    databaseService: DatabaseService.instance,
  );
});

final recentChatsProvider = FutureProvider<List<ChatModel>>((ref) async {
  final String? currentUserId = ref.watch(authNotifierProvider).userId;
  if (currentUserId == null) {
    return const <ChatModel>[];
  }

  return ref.watch(chatRepositoryProvider).fetchRecentChats(currentUserId);
});

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  String roomId,
) {
  final String? currentUserId = ref.watch(authNotifierProvider).userId;
  if (currentUserId == null) {
    return Stream<List<MessageModel>>.value(const <MessageModel>[]);
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
      return thread;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }
}

class ChatThreadRequest {
  const ChatThreadRequest({this.roomId, this.userId});

  final String? roomId;
  final String? userId;

  @override
  bool operator ==(Object other) {
    return other is ChatThreadRequest &&
        other.roomId == roomId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(roomId, userId);
}
