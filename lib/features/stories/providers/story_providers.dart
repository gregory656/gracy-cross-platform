import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show File;

import '../../../shared/models/story_model.dart';
import '../../../shared/services/database_service.dart';
import '../data/story_service.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService.instance);

final storyServiceProvider = Provider<StoryService>((ref) => StoryService());

final storiesProvider = AsyncNotifierProvider<StoriesNotifier, List<StoryModel>>(
  StoriesNotifier.new,
);

class StoriesNotifier extends AsyncNotifier<List<StoryModel>> {
  RealtimeChannel? _channel;

  @override
  Future<List<StoryModel>> build() async {
    final ownerId = Supabase.instance.client.auth.currentUser?.id;
    if (ownerId == null) return [];

    ref.onDispose(_detachRealtime);

    final cached = await ref.read(databaseServiceProvider).getCachedStories(ownerId);
    final active = cached.where((s) => s.isActive).toList();
    if (active.isNotEmpty) {
      _attachRealtime();
      return active;
    }

    await _loadStories(refresh: true);
    _attachRealtime();
    return state.value ?? [];
  }

  Future<void> _loadStories({bool refresh = false}) async {
    state = const AsyncValue.loading();
    try {
      final stories = await ref.read(storyServiceProvider).getActiveStories();
      final ownerId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await ref.read(databaseServiceProvider).cacheStories(stories, ownerId);
      state = AsyncValue.data(stories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _attachRealtime() {
    _channel?.unsubscribe();
    final client = Supabase.instance.client;
    _channel = client.channel('stories');
    _channel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'stories',
      callback: (payload) => _onRealtimeUpdate(payload),
    )
        .subscribe();
  }

  void _detachRealtime() => _channel?.unsubscribe();

  void _onRealtimeUpdate(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    final story = StoryModel.fromMap(newRecord);
    if (!story.isActive) return;

    final List<StoryModel> currentStories = state.asData?.value ?? const <StoryModel>[];
    state = AsyncValue.data(
      <StoryModel>[story, ...currentStories.where((StoryModel s) => s.id != story.id)],
    );
  }

  Future<void> refresh() => _loadStories(refresh: true);

  Future<void> createStory({
    String? content,
    File? imageFile,
  }) async {
    final newStory = await ref.read(storyServiceProvider).createStory(
      content: content,
      imageFile: imageFile,
    );
    final List<StoryModel> currentStories = state.asData?.value ?? const <StoryModel>[];
    state = AsyncValue.data(<StoryModel>[newStory, ...currentStories]);
  }
}

