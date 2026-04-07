import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../../core/secrets.dart';

class OptimizedPostService {
  static final OptimizedPostService _instance =
      OptimizedPostService._internal();
  factory OptimizedPostService() => _instance;
  OptimizedPostService._internal();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  static const int _targetImageWidth = 1080;
  static const int _targetImageHeight = 1080;
  static const int _targetImageQuality = 80;
  static const int _maxUploadBytes = 1000000;
  static const List<String> _postTextColumns = <String>[
    'content',
    'text',
    'caption',
    'body',
    'post_text',
    'description',
    'message',
  ];

  Future<List<PostModel>> getPosts({int limit = 20, int offset = 0}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('posts')
          .select('''
            *,
            profiles!posts_author_id_fkey (
              username,
              avatar_url
            )
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final postRows = (response as List)
          .map((post) => Map<String, dynamic>.from(post as Map))
          .toList(growable: false);
      final postIds = postRows
          .map((post) => post['id'] as String?)
          .whereType<String>()
          .toList(growable: false);
      final likedPostIds = await _fetchLikedPostIds(
        userId: userId,
        postIds: postIds,
      );

      final posts = postRows
          .map(
            (postData) => _mapPost(
              postData,
              isLikedByCurrentUser: likedPostIds.contains(postData['id']),
            ),
          )
          .toList(growable: false);

      return posts;
    } catch (e) {
      _logSupabaseError('Error fetching posts', e);
      return [];
    }
  }

  Future<PostModel> createPost({
    required String content,
    File? imageFile,
    Function(double)? onProgress,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      String? imageUrl;

      if (imageFile != null) {
        onProgress?.call(0.05); // Starting
        await Future<void>.delayed(Duration.zero);

        onProgress?.call(0.2); // Image ready

        try {
          onProgress?.call(0.3); // Starting upload
          imageUrl = await _uploadImageWithRetry(imageFile, userId);
          onProgress?.call(0.8); // Upload complete
        } catch (e) {
          rethrow;
        }
      }

      onProgress?.call(0.9); // Creating post in database

      final postDataWithProfile = await _insertPostRecord(
        userId: userId,
        content: content,
        imageUrl: imageUrl,
      );
      final profile = await _getCurrentProfile(userId);

      final post = PostModel.fromMap({
        ...postDataWithProfile,
        'author_name':
            profile?['username'] as String? ??
            _supabase.auth.currentUser?.userMetadata?['username']?.toString(),
        'author_avatar': profile?['avatar_url'] as String?,
        'is_liked_by_current_user': false,
      });

      onProgress?.call(1.0); // Complete

      // Check if this is the user's first post and trigger bot like
      _checkAndTriggerBotLike(post.id, userId);

      return post;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  Future<String> _uploadImageWithRetry(
    File compressedFile,
    String userId,
  ) async {
    const maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await _uploadImageInBackground(compressedFile, userId);
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow;
        }

        // Wait before retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    throw Exception('Upload failed after $maxRetries attempts');
  }

  Future<File?> _compressImage(File imageFile) async {
    try {
      var quality = _targetImageQuality;
      File? compressed;

      while (quality >= 45) {
        final result = await FlutterImageCompress.compressAndGetFile(
          imageFile.path,
          '${imageFile.parent.path}/temp_compressed_${DateTime.now().millisecondsSinceEpoch}_$quality.jpg',
          quality: quality,
          minWidth: _targetImageWidth,
          minHeight: _targetImageHeight,
        );

        if (result == null) {
          return null;
        }

        compressed = File(result.path);
        final length = await compressed.length();
        if (length <= _maxUploadBytes) {
          return compressed;
        }

        await _deleteTemporaryFile(compressed);
        quality -= 10;
      }

      return compressed;
    } catch (e) {
      debugPrint('Image compression error: $e');
      return null;
    }
  }

  Future<String> _uploadImageInBackground(
    File compressedFile,
    String userId,
  ) async {
    try {
      final cloudinary = CloudinaryPublic(
        CloudinaryConfig.cloudName,
        CloudinaryConfig.unsignedPreset,
        cache: false,
      );

      final response = await cloudinary
          .uploadFile(
            CloudinaryFile.fromFile(
              compressedFile.path,
              resourceType: CloudinaryResourceType.Image,
              folder: 'gracy_posts',
            ),
          )
          .timeout(const Duration(seconds: 30));

      return response.secureUrl;
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  Future<void> _checkAndTriggerBotLike(String postId, String userId) async {
    try {
      // Check if this is the user's first post
      final userPosts = await _supabase
          .from('posts')
          .select('id')
          .eq('author_id', userId);

      if (userPosts.length == 1) {
        // This is the first post, trigger bot like after 10 seconds
        Future.delayed(const Duration(seconds: 10), () async {
          await _likePostAsBot(postId);
        });
      }
    } catch (e) {
      // Log error but don't throw since this is a background operation
      debugPrint('Failed to check first post status: $e');
    }
  }

  Future<Map<String, dynamic>?> _getCurrentProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _insertPostRecord({
    required String userId,
    required String content,
    required String? imageUrl,
  }) async {
    final baseData = <String, dynamic>{
      'author_id': userId,
      'image_url': imageUrl,
      'likes_count': 0,
      'comments_count': 0,
    };
    final trimmedContent = content.trim();
    final candidateColumns = trimmedContent.isEmpty
        ? <String?>[null]
        : _postTextColumns.cast<String?>();

    Object? lastError;

    for (final column in candidateColumns) {
      final postData = Map<String, dynamic>.from(baseData);
      if (column != null) {
        postData[column] = trimmedContent;
      }

      try {
        final response = await _supabase
            .from('posts')
            .insert(postData)
            .select()
            .single();
        return Map<String, dynamic>.from(response);
      } catch (e) {
        lastError = e;
        if (column != null && _isMissingColumnError(e, column)) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      'Posts table text column is unsupported. Tried: ${_postTextColumns.join(', ')}. Last error: $lastError',
    );
  }

  bool _isMissingColumnError(Object error, String column) {
    final message = error.toString().toLowerCase();
    final missingColumnMessage =
        "could not find '$column' column of 'posts' in the schema cache";
    return message.contains(missingColumnMessage) ||
        (message.contains(column.toLowerCase()) && message.contains('column'));
  }

  String? _resolvePostTextColumn(Map<String, dynamic> postData) {
    for (final column in _postTextColumns) {
      if (postData.containsKey(column) && postData[column] != null) {
        return column;
      }
    }

    for (final column in _postTextColumns) {
      if (postData.containsKey(column)) {
        return column;
      }
    }

    return null;
  }

  Future<void> _updatePostTextRecord({
    required String postId,
    required String content,
    String? preferredColumn,
  }) async {
    final orderedColumns = <String>[
      ?preferredColumn,
      ..._postTextColumns.where((column) => column != preferredColumn),
    ];

    Object? lastError;

    for (final column in orderedColumns) {
      try {
        await _supabase
            .from('posts')
            .update({column: content})
            .eq('id', postId);
        return;
      } catch (e) {
        lastError = e;
        if (_isMissingColumnError(e, column)) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      'Posts table text column is unsupported. Tried: ${orderedColumns.join(', ')}. Last error: $lastError',
    );
  }

  Future<void> _likePostAsBot(String postId) async {
    try {
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': CloudinaryConfig.gracyBotPid,
      });

      await _incrementLikesCount(postId);
    } catch (e) {
      _logSupabaseError('Failed to like post as bot', e);
    }
  }

  Future<PostModel> toggleLike(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final existingLike = await _supabase
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        await _decrementLikesCount(postId);
      } else {
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });

        await _incrementLikesCount(postId);
      }

      return await getPostById(postId);
    } catch (e) {
      _logSupabaseError('Failed to toggle like', e);
      throw Exception('Failed to toggle like: $e');
    }
  }

  Future<PostModel> getPostById(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('posts')
          .select('''
            *,
            profiles!posts_author_id_fkey (
              username,
              avatar_url
            )
          ''')
          .eq('id', postId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Post not found');
      }

      final postData = Map<String, dynamic>.from(response);
      final likeRecord = userId == null
          ? null
          : await _supabase
                .from('post_likes')
                .select('post_id')
                .eq('post_id', postId)
                .eq('user_id', userId)
                .maybeSingle();

      return _mapPost(postData, isLikedByCurrentUser: likeRecord != null);
    } catch (e) {
      _logSupabaseError('Failed to fetch post', e);
      throw Exception('Failed to fetch post: $e');
    }
  }

  Future<PostModel> updatePostCaption({
    required String postId,
    required String content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('posts')
          .select('*')
          .eq('id', postId)
          .single();
      final postData = Map<String, dynamic>.from(response);

      if (postData['author_id'] != userId) {
        throw Exception('You can only edit your own posts');
      }

      await _updatePostTextRecord(
        postId: postId,
        content: content.trim(),
        preferredColumn: _resolvePostTextColumn(postData),
      );

      return await getPostById(postId);
    } catch (e) {
      _logSupabaseError('Failed to update post', e);
      throw Exception('Failed to update post: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      final post = await _supabase
          .from('posts')
          .select('author_id')
          .eq('id', postId)
          .single();

      if (post['author_id'] != userId) {
        throw Exception('You can only delete your own posts');
      }

      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  Future<List<PostCommentModel>> getComments(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('post_comments')
          .select('''
            *,
            profiles!post_comments_author_id_fkey (
              username,
              avatar_url
            )
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final List<Map<String, dynamic>> commentRows = (response as List)
          .map((dynamic comment) => Map<String, dynamic>.from(comment as Map))
          .toList();
      final List<String> commentIds = commentRows
          .map((Map<String, dynamic> comment) => comment['id'] as String?)
          .whereType<String>()
          .toList();
      final Map<String, int> likesByComment = await _fetchCommentLikeCounts(
        commentIds,
      );
      final Set<String> likedByCurrentUser = userId == null
          ? <String>{}
          : await _fetchLikedCommentIds(userId: userId, commentIds: commentIds);

      return commentRows.map((commentData) {
        final profile = commentData['profiles'] as Map<String, dynamic>?;

        return PostCommentModel.fromMap({
          ...commentData,
          'user_name': profile?['username'] as String?,
          'user_avatar': profile?['avatar_url'] as String?,
          'likes_count': likesByComment[commentData['id']] ?? 0,
          'is_liked_by_current_user': likedByCurrentUser.contains(
            commentData['id'],
          ),
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Future<PostCommentModel> addComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('post_comments')
          .insert({
            'post_id': postId,
            'author_id': userId,
            'parent_id': parentId,
            'content': content,
          })
          .select('''
            *,
            profiles!post_comments_author_id_fkey (
              username,
              avatar_url
            )
          ''')
          .single();

      final Map<String, dynamic> commentData = Map<String, dynamic>.from(
        response,
      );
      final profile = commentData['profiles'] as Map<String, dynamic>?;

      return PostCommentModel.fromMap({
        ...commentData,
        'user_name': profile?['username'] as String?,
        'user_avatar': profile?['avatar_url'] as String?,
      });
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  Future<PostCommentModel> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final existing = await _supabase
          .from('post_comments')
          .select('author_id')
          .eq('id', commentId)
          .single();

      if (existing['author_id'] != userId) {
        throw Exception('You can only edit your own comments');
      }

      final response = await _supabase
          .from('post_comments')
          .update({'content': content.trim()})
          .eq('id', commentId)
          .select('''
            *,
            profiles!post_comments_author_id_fkey (
              username,
              avatar_url
            )
          ''')
          .single();

      final Map<String, dynamic> commentData = Map<String, dynamic>.from(
        response,
      );
      final profile = commentData['profiles'] as Map<String, dynamic>?;

      return PostCommentModel.fromMap({
        ...commentData,
        'user_name': profile?['username'] as String?,
        'user_avatar': profile?['avatar_url'] as String?,
      });
    } catch (e) {
      throw Exception('Failed to update comment: $e');
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final existing = await _supabase
          .from('post_comments')
          .select('author_id')
          .eq('id', commentId)
          .single();

      if (existing['author_id'] != userId) {
        throw Exception('You can only delete your own comments');
      }

      await _supabase.from('post_comments').delete().eq('id', commentId);
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<bool> toggleCommentLike(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final existing = await _supabase
          .from('comment_likes')
          .select('comment_id')
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
        return false;
      }

      await _supabase.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });
      return true;
    } catch (e) {
      throw Exception('Failed to toggle comment like: $e');
    }
  }

  Future<void> reportComment({
    required String commentId,
    required String reason,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('content_reports').insert({
        'reporter_id': userId,
        'target_type': 'comment',
        'target_id': commentId,
        'reason': reason,
      });
    } catch (e) {
      throw Exception('Failed to report comment: $e');
    }
  }

  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('content_reports').insert({
        'reporter_id': userId,
        'target_type': 'post',
        'target_id': postId,
        'reason': reason,
      });
    } catch (e) {
      throw Exception('Failed to report post: $e');
    }
  }

  Future<File?> pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _targetImageWidth.toDouble(),
        maxHeight: _targetImageHeight.toDouble(),
        imageQuality: _targetImageQuality,
      );

      if (pickedFile == null) {
        return null;
      }

      return File(pickedFile.path);
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  Future<File?> compressSelectedImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Selected image no longer exists');
      }

      final compressedFile = await _compressImage(imageFile);
      if (compressedFile == null) {
        throw Exception('Image compression failed');
      }

      return compressedFile;
    } catch (e) {
      throw Exception('Failed to prepare image: $e');
    }
  }

  Future<void> _deleteTemporaryFile(File? file) async {
    if (file == null) {
      return;
    }

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  PostModel _mapPost(
    Map<String, dynamic> postData, {
    required bool isLikedByCurrentUser,
  }) {
    final profile = postData['profiles'] as Map<String, dynamic>?;

    return PostModel.fromMap({
      ...postData,
      'author_name': profile?['username'] as String? ?? 'Unknown User',
      'author_avatar': profile?['avatar_url'] as String?,
      'is_liked_by_current_user': isLikedByCurrentUser,
    });
  }

  Future<Set<String>> _fetchLikedPostIds({
    required String userId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) {
      return <String>{};
    }

    final response = await _supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);

    return (response as List)
        .map((row) => (row as Map<String, dynamic>)['post_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<void> _incrementLikesCount(String postId) async {
    await _supabase.rpc('increment_likes', params: {'post_id_input': postId});
  }

  Future<void> _decrementLikesCount(String postId) async {
    await _supabase.rpc('decrement_likes', params: {'post_id_input': postId});
  }

  Future<Map<String, int>> _fetchCommentLikeCounts(List<String> commentIds) async {
    if (commentIds.isEmpty) {
      return <String, int>{};
    }

    final response = await _supabase
        .from('comment_likes')
        .select('comment_id')
        .inFilter('comment_id', commentIds);

    final Map<String, int> counts = <String, int>{};
    for (final dynamic row in response as List) {
      final String? commentId =
          (row as Map<String, dynamic>)['comment_id'] as String?;
      if (commentId == null) {
        continue;
      }
      counts.update(commentId, (int count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<Set<String>> _fetchLikedCommentIds({
    required String userId,
    required List<String> commentIds,
  }) async {
    if (commentIds.isEmpty) {
      return <String>{};
    }

    final response = await _supabase
        .from('comment_likes')
        .select('comment_id')
        .eq('user_id', userId)
        .inFilter('comment_id', commentIds);

    return (response as List)
        .map((dynamic row) => (row as Map<String, dynamic>)['comment_id'])
        .whereType<String>()
        .toSet();
  }

  void _logSupabaseError(String context, Object error) {
    if (error is PostgrestException) {
      debugPrint('$context: ${error.message}');
      if (error.code case final String code when code.isNotEmpty) {
        debugPrint('$context code: $code');
      }
      if (error.details case final String details when details.isNotEmpty) {
        debugPrint('$context details: $details');
      }
      if (error.hint case final String hint when hint.isNotEmpty) {
        debugPrint('$context hint: $hint');
      }
      return;
    }

    debugPrint('$context: $error');
  }
}
