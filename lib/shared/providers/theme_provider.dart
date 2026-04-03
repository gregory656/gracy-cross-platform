import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_provider.dart';

final themeProvider = NotifierProvider<ThemeNotifier, String>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.watch(currentUserProvider)?.selectedTheme ?? 'midnight';
  }

  Future<void> setTheme(String themeName) async {
    state = themeName;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'selected_theme': themeName})
          .eq('id', userId);
    } catch (_) {
      // Background save. If failure, not interrupting the UI layer.
    }
  }

  Future<void> updateNotifications(bool enabled) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'notifications_enabled': enabled})
          .eq('id', userId);
    } catch (_) {}
  }
}
