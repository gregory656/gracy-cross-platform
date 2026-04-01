import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';

class PresenceService {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  RealtimeChannel? _channel;
  String? _activeUserId;

  Future<void> markOnline(String userId) async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    if (_activeUserId == userId && _channel != null) {
      return;
    }

    await markOffline();

    final SupabaseClient client = Supabase.instance.client;
    final RealtimeChannel channel = client.channel('presence-$userId');

    _channel = channel;
    _activeUserId = userId;

    channel.subscribe();
    await channel.track(<String, dynamic>{
      'user_id': userId,
      'state': 'online',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markOffline() async {
    if (_channel == null) {
      return;
    }

    final RealtimeChannel channel = _channel!;
    _channel = null;
    _activeUserId = null;

    try {
      await channel.untrack();
      await channel.unsubscribe();
    } catch (_) {
      // Presence teardown should never block the UI.
    }

    if (SupabaseConfig.isConfigured) {
      await Supabase.instance.client.removeChannel(channel);
    }
  }
}
