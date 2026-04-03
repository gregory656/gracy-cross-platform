import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../models/connection_model.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';

final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService(ref);
});

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
  return asyncValue.maybeWhen(
    data: (notifications) => notifications.where((e) => !e.isRead).length,
    orElse: () => 0,
  );
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
      await Supabase.instance.client.from('connections').insert({
        'user_id': myId,
        'contact_id': contactId,
        'status': 'pending',
      });
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
    } catch (_) {}
  }
}
