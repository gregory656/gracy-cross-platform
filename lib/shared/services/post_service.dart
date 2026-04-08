import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../../core/secrets.dart';

class PostService {
  static final PostService _instance = PostService._internal();
  factory PostService() => _instance;
  PostService._internal();

  final _cloudinary = CloudinaryPublic(
    CloudinaryConfig.cloudName,
    CloudinaryConfig.unsignedPreset,
    cache: false,
  );

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
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
      final Map<String, int> commentCounts = await _fetchVisibleCommentCounts(
        postIds,
      );

      final posts = postRows
          .map(
            (postData) => _mapPost({
              ...postData,
              'comments_count': commentCounts[postData['id']] ?? 0,
            }, isLikedByCurrentUser: likedPostIds.contains(postData['id'])),
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
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      String? imageUrl;

      if (imageFile != null) {
        imageUrl = await _uploadImageToCloudinary(imageFile);
      }

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

      // Check if this is the user's first post and trigger bot like
      await _checkAndTriggerBotLike(post.id, userId);

      return post;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  Future<String> _uploadImageToCloudinary(File imageFile) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'gracy_posts',
        ),
      );

      return response.secureUrl;
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  Future<void> _checkAndTriggerBotLike(String postId, String userId) async {
    try {
      // Check if this is the user's first post
      final userPostsCount = await _supabase
          .from('posts')
          .select('id')
          .eq('author_id', userId);

      if (userPostsCount.length == 1) {
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
      'view_count': 0,
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

      final Map<String, dynamic> postData = Map<String, dynamic>.from(response);
      final likeRecord = userId == null
          ? null
          : await _supabase
                .from('post_likes')
                .select('post_id')
                .eq('post_id', postId)
                .eq('user_id', userId)
                .maybeSingle();
      final Map<String, int> commentCounts = await _fetchVisibleCommentCounts(
        <String>[postId],
      );

      return _mapPost({
        ...postData,
        'comments_count': commentCounts[postId] ?? 0,
      }, isLikedByCurrentUser: likeRecord != null);
    } catch (e) {
      _logSupabaseError('Failed to fetch post', e);
      throw Exception('Failed to fetch post: $e');
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

      final PostCommentModel existing = await _fetchCommentById(
        commentId,
        userId: userId,
      );

      if (existing.authorId != userId) {
        throw Exception('You can only edit your own comments');
      }

      final Map<String, dynamic>? updated = await _supabase
          .from('post_comments')
          .update({'content': content.trim()})
          .eq('id', commentId)
          .select('id')
          .maybeSingle();

      if (updated == null) {
        throw Exception(
          'Comment update was blocked by Supabase RLS. Add an UPDATE policy that allows the comment author to edit their own comments.',
        );
      }

      return existing.copyWith(content: content.trim(), isPending: false);
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
          .select('author_id, post_id')
          .eq('id', commentId)
          .single();

      final post = await _supabase
          .from('posts')
          .select('author_id')
          .eq('id', existing['post_id'])
          .single();

      final bool isCommentAuthor = existing['author_id'] == userId;
      final bool isPostOwner = post['author_id'] == userId;

      if (!isCommentAuthor && !isPostOwner) {
        throw Exception(
          'You can only delete your own comments or moderate comments on your posts',
        );
      }

      await _supabase.from('post_comments').delete().eq('id', commentId);
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<PostCommentModel> hideComment(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final PostCommentModel existingComment = await _fetchCommentById(
        commentId,
        userId: userId,
      );
      final existing = await _supabase
          .from('post_comments')
          .select('author_id, post_id')
          .eq('id', commentId)
          .single();

      final post = await _supabase
          .from('posts')
          .select('author_id')
          .eq('id', existing['post_id'])
          .single();

      final bool isPostOwner = post['author_id'] == userId;
      if (!isPostOwner) {
        throw Exception('Only the post owner can hide comments');
      }

      final Map<String, dynamic>? updated = await _supabase
          .from('post_comments')
          .update({'is_hidden': true})
          .eq('id', commentId)
          .select('id')
          .maybeSingle();

      if (updated == null) {
        throw Exception(
          'Comment hide was blocked by Supabase RLS. Add an UPDATE policy that allows the post owner to hide comments on their own posts.',
        );
      }

      return existingComment.copyWith(isHidden: true, isPending: false);
    } catch (e) {
      throw Exception('Failed to hide comment: $e');
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
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
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

  Future<void> incrementViewsCount(String postId) async {
    await _supabase.rpc('increment_views', params: {'post_id_input': postId});
  }

  Future<Map<String, int>> _fetchCommentLikeCounts(
    List<String> commentIds,
  ) async {
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

  Future<Map<String, int>> _fetchVisibleCommentCounts(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) {
      return <String, int>{};
    }

    final response = await _supabase
        .from('post_comments')
        .select('post_id')
        .inFilter('post_id', postIds);

    final Map<String, int> counts = <String, int>{};
    for (final dynamic row in response as List) {
      final String? postId =
          (row as Map<String, dynamic>)['post_id'] as String?;
      if (postId == null) {
        continue;
      }
      counts.update(postId, (int count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<PostCommentModel> _fetchCommentById(
    String commentId, {
    required String userId,
  }) async {
    final response = await _supabase
        .from('post_comments')
        .select('''
          *,
          profiles!post_comments_author_id_fkey (
            username,
            avatar_url
          )
        ''')
        .eq('id', commentId)
        .single();

    final Map<String, dynamic> commentData = Map<String, dynamic>.from(
      response,
    );
    final profile = commentData['profiles'] as Map<String, dynamic>?;
    final Map<String, int> likeCounts = await _fetchCommentLikeCounts(<String>[
      commentId,
    ]);
    final Set<String> likedByCurrentUser = await _fetchLikedCommentIds(
      userId: userId,
      commentIds: <String>[commentId],
    );

    return PostCommentModel.fromMap({
      ...commentData,
      'user_name': profile?['username'] as String?,
      'user_avatar': profile?['avatar_url'] as String?,
      'likes_count': likeCounts[commentId] ?? 0,
      'is_liked_by_current_user': likedByCurrentUser.contains(commentId),
    });
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
