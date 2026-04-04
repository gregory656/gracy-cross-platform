import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum DisappearingDuration { off, hours24, days7 }

extension DisappearingDurationExtension on DisappearingDuration {
  String get label {
    switch (this) {
      case DisappearingDuration.off:
        return 'Off';
      case DisappearingDuration.hours24:
        return '24 hours';
      case DisappearingDuration.days7:
        return '7 days';
    }
  }

  Duration? get duration {
    switch (this) {
      case DisappearingDuration.off:
        return null;
      case DisappearingDuration.hours24:
        return const Duration(hours: 24);
      case DisappearingDuration.days7:
        return const Duration(days: 7);
    }
  }

  String get value {
    switch (this) {
      case DisappearingDuration.off:
        return 'off';
      case DisappearingDuration.hours24:
        return '24h';
      case DisappearingDuration.days7:
        return '7d';
    }
  }

  static DisappearingDuration fromString(String value) {
    switch (value.toLowerCase()) {
      case '24h':
        return DisappearingDuration.hours24;
      case '7d':
        return DisappearingDuration.days7;
      default:
        return DisappearingDuration.off;
    }
  }
}

final disappearingMessagesProvider = NotifierProvider<DisappearingMessagesNotifier, DisappearingDuration>(
  DisappearingMessagesNotifier.new,
);

class DisappearingMessagesNotifier extends Notifier<DisappearingDuration> {
  @override
  DisappearingDuration build() => DisappearingDuration.off;

  Future<void> setDuration(DisappearingDuration duration) async {
    state = duration;
    
    // Save to Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'disappearing_messages': duration.value})
          .eq('id', userId);
    } catch (e) {
      // Handle error silently for now
      // print('Failed to save disappearing messages setting: $e');
    }
  }

  Future<void> loadFromDatabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('disappearing_messages')
          .eq('id', userId)
          .single();

      final String? durationValue = response['disappearing_messages'] as String?;
      if (durationValue != null) {
        state = DisappearingDurationExtension.fromString(durationValue);
      }
    } catch (e) {
      // Use default if failed to load
      // print('Failed to load disappearing messages setting: $e');
    }
  }

  DateTime? calculateExpiryTime() {
    final duration = state.duration;
    if (duration == null) return null;
    return DateTime.now().add(duration);
  }
}
