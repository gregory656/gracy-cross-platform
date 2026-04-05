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
            ),
            post_likes!left (
              user_id
            )
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = <PostModel>[];
      
      for (final post in (response as List)) {
        final postData = post as Map<String, dynamic>;
        final profile = postData['profiles'] as Map<String, dynamic>?;
        final likes = postData['post_likes'] as List?;
        
        // Check if current user liked this post
        final isLiked = likes?.any((like) => like['user_id'] == userId) ?? false;
        
        posts.add(PostModel.fromMap({
          ...postData,
          'author_name': profile?['username'] as String? ?? 'Unknown User',
          'author_avatar': profile?['avatar_url'] as String?,
          'is_liked_by_current_user': isLiked,
        }));
      }

      return posts;
    } catch (e) {
      // Return empty list on error to prevent crashes
      debugPrint('Error fetching posts: $e');
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

      final postData = {
        'author_id': userId,
        'content': content,
        'image_url': imageUrl,
        'likes_count': 0,
        'comments_count': 0,
      };

      final response = await _supabase
          .from('posts')
          .insert(postData)
          .select('''
            *,
            profiles!posts_author_id_fkey (
              username,
              avatar_url
            )
          ''')
          .single();

      final Map<String, dynamic> postDataWithProfile =
          Map<String, dynamic>.from(response);
      final profile = postDataWithProfile['profiles'] as Map<String, dynamic>?;

      final post = PostModel.fromMap({
        ...postDataWithProfile,
        'author_name': profile?['username'] as String?,
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

  Future<void> _likePostAsBot(String postId) async {
    try {
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': CloudinaryConfig.gracyBotPid,
      });

      await _supabase
          .from('posts')
          .update({'likes_count': _supabase.rpc('increment')})
          .eq('id', postId);
    } catch (e) {
      debugPrint('Failed to like post as bot: $e');
    }
  }

  Future<PostModel> toggleLike(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if already liked
      final existingLike = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        await _supabase.rpc('decrement', params: {'table_name': 'posts', 'id': postId, 'column_name': 'likes_count'});
      } else {
        // Like
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });

        await _supabase.rpc('increment', params: {'table_name': 'posts', 'id': postId, 'column_name': 'likes_count'});
      }

      // Fetch updated post
      return await getPostById(postId);
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  Future<PostModel> getPostById(String postId) async {
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
            ),
            post_likes!left (
              user_id
            )
          ''')
          .eq('id', postId)
          .single();

      final Map<String, dynamic> postData = Map<String, dynamic>.from(response);
      final profile = postData['profiles'] as Map<String, dynamic>?;
      final likes = postData['post_likes'] as List?;

      // Check if current user liked this post
      final isLiked = likes?.any((like) => like['user_id'] == userId) ?? false;

      return PostModel.fromMap({
        ...postData,
        'author_name': profile?['username'] as String? ?? 'Unknown User',
        'author_avatar': profile?['avatar_url'] as String?,
        'is_liked_by_current_user': isLiked,
      });
    } catch (e) {
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
      final response = await _supabase
          .from('post_comments')
          .select('''
            *,
            profiles!post_comments_user_id_fkey (
              username,
              avatar_url
            )
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (response as List).map((comment) {
        final commentData = comment as Map<String, dynamic>;
        final profile = commentData['profiles'] as Map<String, dynamic>?;
        
        return PostCommentModel.fromMap({
          ...commentData,
          'user_name': profile?['username'] as String?,
          'user_avatar': profile?['avatar_url'] as String?,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Future<PostCommentModel> addComment({
    required String postId,
    required String content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('post_comments')
          .insert({
            'post_id': postId,
            'user_id': userId,
            'content': content,
          })
          .select('''
            *,
            profiles!post_comments_user_id_fkey (
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
}
