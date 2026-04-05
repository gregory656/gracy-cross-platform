import 'dart:io';
import 'dart:isolate';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../../core/secrets.dart';

// Isolate data structure for background upload
class UploadIsolateData {
  final String imagePath;
  final String cloudName;
  final String unsignedPreset;
  final String userId;
  final String content;

  UploadIsolateData({
    required this.imagePath,
    required this.cloudName,
    required this.unsignedPreset,
    required this.userId,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'cloudName': cloudName,
      'unsignedPreset': unsignedPreset,
      'userId': userId,
      'content': content,
    };
  }

  static UploadIsolateData fromMap(Map<String, dynamic> map) {
    return UploadIsolateData(
      imagePath: map['imagePath'],
      cloudName: map['cloudName'],
      unsignedPreset: map['unsignedPreset'],
      userId: map['userId'],
      content: map['content'],
    );
  }
}

// Background upload result
class UploadResult {
  final bool success;
  final String? imageUrl;
  final String? error;

  UploadResult({required this.success, this.imageUrl, this.error});

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'imageUrl': imageUrl,
      'error': error,
    };
  }

  static UploadResult fromMap(Map<String, dynamic> map) {
    return UploadResult(
      success: map['success'],
      imageUrl: map['imageUrl'],
      error: map['error'],
    );
  }
}

// Background isolate entry point
void _uploadIsolateEntryPoint(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is UploadIsolateData) {
      try {
        // Compress image in background
        final compressedFile = await _compressImageInBackground(message.imagePath);
        
        if (compressedFile == null) {
          sendPort.send(UploadResult(success: false, error: 'Image compression failed'));
          continue;
        }

        // Upload to Cloudinary in background
        final cloudinary = CloudinaryPublic(message.cloudName, message.unsignedPreset);
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            compressedFile.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'gracy_posts',
          ),
        ).timeout(const Duration(seconds: 30));

        final String imageUrl = response.secureUrl;
        
        // Clean up compressed file
        await compressedFile.delete();

        sendPort.send(UploadResult(success: true, imageUrl: imageUrl));
      } catch (e) {
        sendPort.send(UploadResult(success: false, error: e.toString()));
      }
    }
  }
}

// Image compression in background
Future<File?> _compressImageInBackground(String imagePath) async {
  try {
    final file = File(imagePath);
    final result = await FlutterImageCompress.compressAndGetFile(
      imagePath,
      '${file.parent.path}/temp_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      quality: 80,
      minWidth: 1024,
      minHeight: 1024,
    );
    return result != null ? File(result.path) : null;
  } catch (e) {
    return null;
  }
}

class OptimizedPostService {
  static final OptimizedPostService _instance = OptimizedPostService._internal();
  factory OptimizedPostService() => _instance;
  OptimizedPostService._internal();

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
              id,
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
      print('Error fetching posts: $e');
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
        
        // Compress image first with better error handling
        final compressedFile = await _compressImage(imageFile);
        
        if (compressedFile == null) {
          throw Exception('Image compression failed - file may be corrupted');
        }
        
        onProgress?.call(0.2); // Compression done
        
        // Upload with timeout and retry logic
        try {
          onProgress?.call(0.3); // Starting upload
          imageUrl = await _uploadImageWithRetry(compressedFile, userId);
          onProgress?.call(0.8); // Upload complete
        } catch (e) {
          // Clean up compressed file even if upload fails
          try {
            await compressedFile.delete();
          } catch (_) {}
          rethrow;
        }
        
        // Clean up compressed file
        try {
          await compressedFile.delete();
        } catch (_) {}
      }

      onProgress?.call(0.9); // Creating post in database

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

      final postDataWithProfile = response as Map<String, dynamic>;
      final profile = postDataWithProfile['profiles'] as Map<String, dynamic>?;

      final post = PostModel.fromMap({
        ...postDataWithProfile,
        'author_name': profile?['username'] as String?,
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

  Future<String> _uploadImageWithRetry(File compressedFile, String userId) async {
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
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        '${imageFile.parent.path}/temp_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
      );
      return result != null ? File(result.path) : null;
    } catch (e) {
      print('Image compression error: $e');
      return null;
    }
  }

  Future<String> _uploadImageInBackground(File compressedFile, String userId) async {
    try {
      final cloudinary = CloudinaryPublic(
        CloudinaryConfig.cloudName,
        CloudinaryConfig.unsignedPreset,
        cache: false,
      );

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          compressedFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'gracy_posts',
        ),
      ).timeout(const Duration(seconds: 30));

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
      print('Failed to check first post status: $e');
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
      print('Failed to like post as bot: $e');
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
              id,
              user_id
            )
          ''')
          .eq('id', postId)
          .single();

      final postData = response;
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

      final commentData = response as Map<String, dynamic>;
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
