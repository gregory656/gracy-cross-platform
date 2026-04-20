import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../models/connection_model.dart';
import '../models/notification_model.dart';
import '../../features/chat/providers/chat_providers.dart';
import 'auth_provider.dart';

final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService(ref);
});

final localReadChatsProvider =
    NotifierProvider<LocalReadChatsController, Map<String, DateTime>>(
      LocalReadChatsController.new,
    );

final chatVisibilityProvider =
    NotifierProvider<ChatVisibilityController, Map<String, ChatVisibility>>(
      ChatVisibilityController.new,
    );

final locallyReadNotificationIdsProvider =
    NotifierProvider<LocallyReadNotificationIdsController, Set<int>>(
      LocallyReadNotificationIdsController.new,
    );

final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((
  ref,
) {
  if (!SupabaseConfig.isConfigured) return Stream.value([]);

  final authState = ref.watch(authNotifierProvider);
  if (authState.userId == null) return Stream.value([]);

  try {
    return Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', authState.userId!)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => NotificationModel.fromMap(e)).toList());
  } catch (_) {
    return Stream.value([]);
  }
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final asyncValue = ref.watch(notificationsStreamProvider);
  final Set<int> locallyReadIds = ref.watch(locallyReadNotificationIdsProvider);
  return asyncValue.maybeWhen(
    data: (notifications) => notifications
        .where((e) => !e.isRead && !locallyReadIds.contains(e.id))
        .length,
    orElse: () => 0,
  );
});

final unreadMessagesCountProvider = Provider<int>((ref) {
  final recentChatsAsync = ref.watch(recentChatsProvider);
  final Map<String, DateTime> locallyReadChats = ref.watch(
    localReadChatsProvider,
  );
  final Map<String, ChatVisibility> chatVisibility = ref.watch(
    chatVisibilityProvider,
  );
  return recentChatsAsync.maybeWhen(
    data: (snapshot) => snapshot.data.fold<int>(0, (int total, chat) {
      if (chatVisibility[chat.id] != null &&
          chatVisibility[chat.id] != ChatVisibility.visible) {
        return total;
      }
      final DateTime? clearedAt = locallyReadChats[chat.id];
      final bool wasClearedAfterLatestMessage =
          clearedAt != null && !chat.lastMessageAt.isAfter(clearedAt);
      if (wasClearedAfterLatestMessage) {
        return total;
      }
      return total + chat.unreadCount;
    }),
    orElse: () => 0,
  );
});

final notificationBellCountProvider = Provider<int>((ref) {
  final int notificationCount = ref.watch(unreadNotificationsCountProvider);
  final int messageCount = ref.watch(unreadMessagesCountProvider);
  return notificationCount + messageCount;
});

final connectionsStreamProvider = StreamProvider<List<ConnectionModel>>((ref) {
  if (!SupabaseConfig.isConfigured) return Stream.value([]);

  final authState = ref.watch(authNotifierProvider);
  if (authState.userId == null) return Stream.value([]);

  final userId = authState.userId!;
  try {
    final stream1 = Supabase.instance.client
        .from('connections')
        .stream(primaryKey: ['user_id', 'contact_id'])
        .eq('user_id', userId);

    final stream2 = Supabase.instance.client
        .from('connections')
        .stream(primaryKey: ['user_id', 'contact_id'])
        .eq('contact_id', userId);

    final controller = StreamController<List<ConnectionModel>>();
    List<Map<String, dynamic>> data1 = [];
    List<Map<String, dynamic>> data2 = [];

    void emit() {
      final allData = [...data1, ...data2];
      controller.add(allData.map((e) => ConnectionModel.fromMap(e)).toList());
    }

    final sub1 = stream1.listen((data) {
      data1 = data;
      emit();
    });

    final sub2 = stream2.listen((data) {
      data2 = data;
      emit();
    });

    ref.onDispose(() {
      sub1.cancel();
      sub2.cancel();
      controller.close();
    });

    return controller.stream;
  } catch (_) {
    return Stream.value([]);
  }
});

final connectionStatusProvider = Provider.family<String?, String>((
  ref,
  contactId,
) {
  final authState = ref.watch(authNotifierProvider);
  final myId = authState.userId;
  if (myId == null || myId == contactId) return null;

  final asyncValue = ref.watch(connectionsStreamProvider);
  return asyncValue.maybeWhen(
    data: (connections) {
      for (final conn in connections) {
        if ((conn.userId == myId && conn.contactId == contactId) ||
            (conn.userId == contactId && conn.contactId == myId)) {
          return conn.status; // 'pending' or 'connected'
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

class SocialService {
  SocialService(this.ref);
  final Ref ref;

  Future<void> sendConnectionRequest(String contactId) async {
    if (!SupabaseConfig.isConfigured) return;
    final myId = ref.read(authNotifierProvider).userId;
    if (myId == null) return;

    try {
      final Map<String, dynamic>? existing = await Supabase.instance.client
          .from('connections')
          .select('status')
          .eq('user_id', myId)
          .eq('contact_id', contactId)
          .maybeSingle();

      if (existing != null) {
        return;
      }

      await Supabase.instance.client.from('connections').insert({
        'user_id': myId,
        'contact_id': contactId,
        'status': 'pending',
      });

      await Supabase.instance.client.from('notifications').insert({
        'receiver_id': contactId,
        'sender_id': myId,
        'type': 'connection_request',
        'content': 'sent you a connection request',
        'is_read': false,
      });
    } catch (_) {}
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    ref
        .read(locallyReadNotificationIdsProvider.notifier)
        .markRead(notificationId);
    if (!SupabaseConfig.isConfigured) return;

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (_) {}
  }

  Future<void> acceptConnection(NotificationModel notif) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      // The notification tells us who sent it. The sender is notif.senderId, receiver is me.
      // So connections row has user_id = senderId, contact_id = myId
      await Supabase.instance.client
          .from('connections')
          .update({'status': 'connected'})
          .match({'user_id': notif.senderId, 'contact_id': notif.receiverId});

      // Mark notification as read (can optionally update type to 'request_accepted' if we notify the other way around)
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notif.id);
      ref.read(locallyReadNotificationIdsProvider.notifier).markRead(notif.id);
    } catch (_) {}
  }

  Future<void> declineConnection(NotificationModel notif) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.instance.client.from('connections').delete().match({
        'user_id': notif.senderId,
        'contact_id': notif.receiverId,
      });

      // Delete the notification
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', notif.id);
      ref.read(locallyReadNotificationIdsProvider.notifier).markRead(notif.id);
    } catch (_) {}
  }
}

class LocalReadChatsController extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => <String, DateTime>{};

  void markRead(String roomId, {DateTime? at}) {
    state = <String, DateTime>{
      ...state,
      roomId: at ?? DateTime.now(),
    };
  }
}

enum ChatVisibility { visible, hidden, archived, deleted }

class ChatVisibilityController extends Notifier<Map<String, ChatVisibility>> {
  @override
  Map<String, ChatVisibility> build() => <String, ChatVisibility>{};

  Future<void> setVisibility(String roomId, ChatVisibility visibility) async {
    final authState = ref.read(authNotifierProvider);
    if (authState.userId == null) return;

    try {
      if (visibility == ChatVisibility.visible) {
        // Try to unhide using flexible function
        await Supabase.instance.client.rpc('unhide_chat_room', params: {
          'p_room_id': roomId,
          'p_user_id': authState.userId,
        });
      } else if (visibility == ChatVisibility.hidden || visibility == ChatVisibility.deleted) {
        // Try to hide using flexible function
        await Supabase.instance.client.rpc('hide_chat_room', params: {
          'p_room_id': roomId,
          'p_user_id': authState.userId,
        });
      } else if (visibility == ChatVisibility.archived) {
        // Archive using chat_members table
        await Supabase.instance.client.rpc('archive_chat_room', params: {
          'p_room_id': roomId,
          'p_user_id': authState.userId,
        });
      }

      // Update local state
      if (visibility == ChatVisibility.visible) {
        final Map<String, ChatVisibility> next = <String, ChatVisibility>{
          ...state,
        };
        next.remove(roomId);
        state = next;
        return;
      }

      state = <String, ChatVisibility>{...state, roomId: visibility};
    } catch (e) {
      debugPrint('Error setting chat visibility: $e');
      // If database update fails, still update local state for immediate UI feedback
      if (visibility == ChatVisibility.visible) {
        final Map<String, ChatVisibility> next = <String, ChatVisibility>{
          ...state,
        };
        next.remove(roomId);
        state = next;
        return;
      }

      state = <String, ChatVisibility>{...state, roomId: visibility};
    }
  }

  Future<void> loadVisibilityFromDatabase() async {
    final authState = ref.read(authNotifierProvider);
    if (authState.userId == null) return;

    try {
      final Map<String, ChatVisibility> visibilityMap = <String, ChatVisibility>{};
      
      // Try loading from chat_rooms with hidden_by array
      try {
        final roomsData = await Supabase.instance.client
            .from('chat_rooms')
            .select('id, hidden_by, is_hidden');

        for (final row in roomsData) {
          final roomId = row['id'] as String;
          final hiddenBy = row['hidden_by'] as List? ?? [];
          final isHidden = row['is_hidden'] as bool? ?? false;
          
          if (hiddenBy.contains(authState.userId) || isHidden) {
            visibilityMap[roomId] = ChatVisibility.hidden;
          }
        }
      } catch (e) {
        debugPrint('hidden_by array not available, trying is_hidden flag: $e');
      }

      // Try loading from chat_members for archived chats
      try {
        final membersData = await Supabase.instance.client
            .from('chat_members')
            .select('room_id, is_archived')
            .eq('user_id', authState.userId!)
            .eq('is_archived', true);

        for (final row in membersData) {
          final roomId = row['room_id'] as String;
          visibilityMap[roomId] = ChatVisibility.archived;
        }
      } catch (e) {
        debugPrint('chat_members table not available: $e');
      }

      state = visibilityMap;
    } catch (e) {
      debugPrint('Error loading visibility from database: $e');
      // Keep existing state if database load fails
    }
  }
}

class LocallyReadNotificationIdsController extends Notifier<Set<int>> {
  @override
  Set<int> build() => <int>{};

  void markRead(int notificationId) {
    state = <int>{...state, notificationId};
  }
}
