import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/services/post_service.dart';
import '../../../shared/services/optimized_post_service.dart';

final postServiceProvider = Provider<PostService>((ref) {
  return PostService();
});

final optimizedPostServiceProvider = Provider<OptimizedPostService>((ref) {
  return OptimizedPostService();
});

final postByIdProvider = FutureProvider.autoDispose.family<PostModel, String>((
  ref,
  String postId,
) {
  return ref.read(optimizedPostServiceProvider).getPostById(postId);
});

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<PostModel>>(
  () => PostsNotifier(),
);

// Simple progress tracking using providers
final uploadProgressProvider = Provider<double>((ref) => 0.0);
final uploadStatusProvider = Provider<String>((ref) => '');

class PostsNotifier extends AsyncNotifier<List<PostModel>> {
  late final OptimizedPostService _postService;
  final List<PostModel> _posts = [];
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  double _currentProgress = 0.0;
  String _currentStatus = '';

  @override
  Future<List<PostModel>> build() async {
    _postService = ref.read(optimizedPostServiceProvider);
    await _loadPosts();
    return _posts;
  }

  // Getters for progress tracking
  double get progress => _currentProgress;
  String get status => _currentStatus;

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
      _posts.clear();
    }

    if (!_hasMore) return;

    state = const AsyncValue.loading();

    try {
      final newPosts = await _postService.getPosts(
        limit: _limit,
        offset: _offset,
      );

      if (refresh) {
        _posts.clear();
      }

      _posts.addAll(newPosts);
      _offset += _limit;
      _hasMore = newPosts.length == _limit;

      state = AsyncValue.data(List.from(_posts));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadPosts(refresh: true);
  }

  Future<void> loadMore() async {
    if (!state.isLoading && _hasMore) {
      await _loadPosts();
    }
  }

  Future<void> createPost({required String content, File? imageFile}) async {
    try {
      _currentProgress = 0.0;
      _currentStatus = 'Preparing post...';
      state = AsyncValue.data(List.from(_posts));

      await Future<void>.delayed(Duration.zero);

      final newPost = await _postService.createPost(
        content: content,
        imageFile: imageFile,
        onProgress: (progress) {
          _currentProgress = progress;
          if (progress < 0.2) {
            _currentStatus = 'Preparing image...';
          } else if (progress < 0.8) {
            _currentStatus = 'Uploading image...';
          } else if (progress < 0.9) {
            _currentStatus = 'Creating post...';
          } else {
            _currentStatus = 'Almost done...';
          }
          state = AsyncValue.data(List.from(_posts));
        },
      );

      _posts.insert(0, newPost);
      state = AsyncValue.data(List.from(_posts));

      _currentProgress = 0.0;
      _currentStatus = '';
      state = AsyncValue.data(List.from(_posts));
    } catch (e, stackTrace) {
      _currentProgress = 0.0;
      _currentStatus = '';
      state = AsyncValue.data(List.from(_posts));
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    PostModel? originalPost;

    if (index != -1) {
      originalPost = _posts[index];
      final isCurrentlyLiked = originalPost.isLikedByCurrentUser;
      final nextLikesCount = isCurrentlyLiked
          ? (originalPost.likesCount > 0 ? originalPost.likesCount - 1 : 0)
          : originalPost.likesCount + 1;

      _posts[index] = originalPost.copyWith(
        isLikedByCurrentUser: !isCurrentlyLiked,
        likesCount: nextLikesCount,
      );
      state = AsyncValue.data(List.from(_posts));
    }

    try {
      final updatedPost = await _postService.toggleLike(postId);

      if (index != -1) {
        _posts[index] = updatedPost;
        state = AsyncValue.data(List.from(_posts));
      }
    } catch (e) {
      if (index != -1 && originalPost != null) {
        _posts[index] = originalPost;
        state = AsyncValue.data(List.from(_posts));
      }
      rethrow;
    }
  }

  Future<void> updatePostCaption({
    required String postId,
    required String content,
  }) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) {
      await _postService.updatePostCaption(postId: postId, content: content);
      return;
    }

    final originalPost = _posts[index];
    final optimisticPost = originalPost.copyWith(
      content: content.trim(),
      updatedAt: DateTime.now(),
    );

    _posts[index] = optimisticPost;
    state = AsyncValue.data(List<PostModel>.from(_posts));

    try {
      final updatedPost = await _postService.updatePostCaption(
        postId: postId,
        content: content,
      );

      _posts[index] = updatedPost;
      state = AsyncValue.data(List<PostModel>.from(_posts));
    } catch (e, stackTrace) {
      _posts[index] = originalPost;
      state = AsyncValue.data(List<PostModel>.from(_posts));
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  Future<void> deletePost(String postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    PostModel? removedPost;

    if (index != -1) {
      removedPost = _posts.removeAt(index);
      state = AsyncValue.data(List<PostModel>.from(_posts));
    }

    try {
      await _postService.deletePost(postId);
    } catch (e, stackTrace) {
      if (removedPost != null) {
        _posts.insert(index, removedPost);
        state = AsyncValue.data(List<PostModel>.from(_posts));
      }
      Error.throwWithStackTrace(e, stackTrace);
    }
  }
}

// Realtime provider for post updates
final postRealtimeProvider = StreamProvider<List<PostModel>>((ref) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) {
        return data.map((post) => PostModel.fromMap(post)).toList();
      });
});
