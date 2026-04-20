import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/story_model.dart';
import '../../../shared/services/database_service.dart';
import 'dart:io' show File;

class StoryService {
  StoryService();

  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _localDb = DatabaseService.instance;

  Future<List<StoryModel>> getActiveStories({String? userId}) async {
    try {
      final ownerId = _supabase.auth.currentUser?.id;
      if (ownerId == null) throw 'No auth';

      // Try cache first
      final cached = await _localDb.getCachedStories(ownerId);
      final activeCached = cached.where((s) => s.isActive).toList();
      if (activeCached.isNotEmpty) return activeCached;

      // Supabase query
      dynamic query = _supabase
          .from('active_stories')
          .select('*, profiles!user_id (full_name, avatar_url)');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      final data = await query.order('created_at', ascending: false);
      final stories = data.map<StoryModel>((dynamic item) {
        final Map<String, dynamic> storyMap = Map<String, dynamic>.from(item);
        final Map<String, dynamic>? profile = storyMap['profiles'];
        return StoryModel(
          id: storyMap['id'],
          userId: storyMap['user_id'],
          content: storyMap['content'],
          imageUrl: storyMap['image_url'],
          createdAt: DateTime.parse(storyMap['created_at']),
          expiresAt: DateTime.parse(storyMap['expires_at']),
          viewedBy: List<String>.from(storyMap['viewed_by'] ?? []),
          authorName: profile?['full_name'] ?? 'Story User',
          authorAvatar: profile?['avatar_url'],
        );
      }).toList();

      // Cache
      await _localDb.cacheStories(stories, ownerId);
      return stories;
    } catch (e) {
      rethrow;
    }
  }

  Future<StoryModel> createStory({
    String? content,
    File? imageFile,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'Auth required';

    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    // Upload image if present
    String? imageUrl;
    if (imageFile != null) {
      final fileName = '${Uuid().v4()}.jpg';
      await _supabase.storage
          .from('stories')
          .upload(fileName, imageFile, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      imageUrl = _supabase.storage.from('stories').getPublicUrl(fileName);
    }

    final data = await _supabase.from('stories').insert({
      'user_id': userId,
      'content': content,
      'image_url': imageUrl,
      'expires_at': expiresAt.toIso8601String(),
    }).select().single();

    final story = StoryModel.fromMap(data);
    await _localDb.cacheStories([story], userId);
    return story;
  }

  Future<void> markViewed(String storyId, String viewerId) async {
    await _supabase.from('stories').update({
      'viewed_by': [...(await getViewedBy(storyId)), viewerId],
    }).eq('id', storyId);
  }

  Future<List<String>> getViewedBy(String storyId) async {
    final data = await _supabase.from('stories').select('viewed_by').eq('id', storyId).maybeSingle();
    return (data?['viewed_by'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic value) => value.toString())
        .toList(growable: false);
  }

  Future<void> deleteStory(String storyId) async {
    await _supabase.from('stories').delete().eq('id', storyId);
  }
}

