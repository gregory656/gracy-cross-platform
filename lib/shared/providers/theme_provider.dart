import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import 'auth_provider.dart';

final themeProvider = NotifierProvider<ThemeNotifier, String>(
  ThemeNotifier.new,
);

final isDarkModeProvider = Provider<bool>((ref) {
  final theme = ref.watch(themeProvider);
  return !AppTheme.isLightThemeName(theme);
});

final ghostModeProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isGhostMode ?? false;
});

class ThemeNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.watch(currentUserProvider)?.selectedTheme ?? 'dark';
  }

  Future<void> setTheme(String themeName) async {
    state = themeName;
    ref.read(authNotifierProvider.notifier).syncSelectedTheme(themeName);

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

  Future<void> toggleDarkLightMode() async {
    final String newTheme = AppTheme.isLightThemeName(state)
        ? 'midnight'
        : 'classic';
    await setTheme(newTheme);
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

  Future<void> updateGhostMode(bool enabled) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_ghost_mode': enabled})
          .eq('id', userId);
      
      // Refresh the user data
      ref.invalidate(currentUserProvider);
    } catch (_) {}
  }
}
