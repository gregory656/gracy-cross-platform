import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../shared/models/feed_category.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/providers/offline_banner_provider.dart';
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

final userPostsProvider = FutureProvider.autoDispose.family<List<PostModel>, String>((
  ref,
  String userId,
) {
  return ref.read(optimizedPostServiceProvider).getPostsByAuthor(userId);
});

final totalReachProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  String userId,
) {
  return ref.read(optimizedPostServiceProvider).getTotalReach(userId);
});

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<PostModel>>(
  () => PostsNotifier(),
);

// Simple progress tracking using providers
final uploadProgressProvider = Provider<double>((ref) => 0.0);
final uploadStatusProvider = Provider<String>((ref) => '');

class PostsNotifier extends AsyncNotifier<List<PostModel>> {
  static final Set<String> _trackedViewPostIds = <String>{};
  late final OptimizedPostService _postService;
  final List<PostModel> _posts = [];
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 10;

  double _currentProgress = 0.0;
  String _currentStatus = '';

  /// `null` means the global **All** feed (no `category` filter).
  String? _feedCategory;
  RealtimeChannel? _postsChannel;

  String? get activeFeedCategory => _feedCategory;

  @override
  Future<List<PostModel>> build() async {
    _postService = ref.read(optimizedPostServiceProvider);
    ref.onDispose(_detachRealtime);
    await _loadPosts();
    _attachRealtime();
    return _posts;
  }

  void _detachRealtime() {
    _postsChannel?.unsubscribe();
    _postsChannel = null;
  }

  void _attachRealtime() {
    if (!SupabaseConfig.isConfigured) {
      return;
    }
    _detachRealtime();
    final SupabaseClient client = Supabase.instance.client;
    _postsChannel = client.channel('home_feed_${_feedCategory ?? 'all'}');
    _postsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'posts',
      callback: (PostgresChangePayload payload) {
        unawaited(_onRealtimeInsert(payload));
      },
    ).subscribe();
  }

  Future<void> _onRealtimeInsert(PostgresChangePayload payload) async {
    final record = payload.newRecord;
    final String? id = record['id'] as String?;
    if (id == null) {
      return;
    }
    if (_feedCategory != null && record['category'] != _feedCategory) {
      return;
    }
    if (_posts.any((PostModel p) => p.id == id)) {
      return;
    }
    
    // Additional check: if this is the current user's own post, don't add it again
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null && record['author_id'] == currentUserId) {
      return;
    }
    try {
      final PostModel post = await _postService.getPostById(id);
      if (_feedCategory != null && post.category != _feedCategory) {
        return;
      }
      _posts.insert(0, post);
      state = AsyncValue<List<PostModel>>.data(List<PostModel>.from(_posts));
    } catch (_) {}
  }

  Future<void> setFeedCategory(String? categorySlug) async {
    if (_feedCategory == categorySlug) {
      return;
    }
    _feedCategory = categorySlug;
    _detachRealtime();
    await _loadPosts(refresh: true);
    _attachRealtime();
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

    if (_posts.isEmpty) {
      state = const AsyncValue.loading();
    }

    try {
      final newPosts = await _postService.getPosts(
        limit: _limit,
        offset: _offset,
        categoryFilter: _feedCategory,
      );
      
      ref.read(offlineBannerProvider.notifier).resetOfflineCachedContentNotice();

      if (refresh) {
        _posts.clear();
      }

      // WORKAROUND: Handle ANY database schema gracefully
      final filteredPosts = newPosts.where((post) {
        // If database has no category support, just include everything
        // Silent Confessions will be identified by content analysis
        final content = post.content.toLowerCase();
        
        // Multiple detection methods for Silent Confessions
        final isConfession = 
            content.contains('confession') ||
            content.contains('silent confession') ||
            content.contains('anonymous confession') ||
            post.authorName == null ||
            post.authorName == 'Anonymous Scion' ||
            (post.authorName?.toLowerCase().contains('anonymous') ?? false);
        
        // Always include confessions regardless of category field
        if (isConfession) {
          return true;
        }
        
        // Include all other posts
        return true;
      }).toList();

      _posts.addAll(filteredPosts);
      _offset += _limit;
      _hasMore = newPosts.length == _limit;

      state = AsyncValue.data(List.from(_posts));
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error loading posts: $e');
      }
      
      if (_posts.isNotEmpty) {
        ref.read(offlineBannerProvider.notifier).showOfflineCachedContentOnce();
        state = AsyncValue.data(List<PostModel>.from(_posts));
        return;
      }
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

  Future<void> createPost({
    required String content,
    File? imageFile,
    String category = FeedCategories.discussions,
    bool isAnonymous = false,
    Map<String, dynamic>? extra,
  }) async {
    try {
      _currentProgress = 0.0;
      _currentStatus = 'Preparing post...';
      state = AsyncValue.data(List.from(_posts));

      await Future<void>.delayed(Duration.zero);

      final newPost = await _postService.createPost(
        content: content,
        imageFile: imageFile,
        category: category,
        isAnonymous: isAnonymous,
        extra: extra,
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

      if (_feedCategory == null || newPost.category == _feedCategory) {
        _posts.insert(0, newPost);
      }
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

  Future<void> trackPostView(String postId) async {
    if (_trackedViewPostIds.contains(postId)) {
      return;
    }

    final index = _posts.indexWhere((post) => post.id == postId);
    PostModel? originalPost;

    _trackedViewPostIds.add(postId);

    if (index != -1) {
      originalPost = _posts[index];
      _posts[index] = originalPost.copyWith(viewCount: originalPost.viewCount + 1);
      state = AsyncValue.data(List<PostModel>.from(_posts));
    }

    try {
      await _postService.incrementViewsCount(postId);
    } catch (e) {
      _trackedViewPostIds.remove(postId);
      if (index != -1 && originalPost != null) {
        _posts[index] = originalPost;
        state = AsyncValue.data(List<PostModel>.from(_posts));
      }
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

  Future<void> setLikesVisibility({
    required String postId,
    required bool isVisible,
  }) async {
    final int index = _posts.indexWhere((PostModel post) => post.id == postId);
    PostModel? originalPost;

    if (index != -1) {
      originalPost = _posts[index];
      _posts[index] = originalPost.copyWith(likesVisible: isVisible);
      state = AsyncValue.data(List<PostModel>.from(_posts));
    }

    try {
      final PostModel updatedPost = await _postService.setLikesVisibility(
        postId: postId,
        isVisible: isVisible,
      );
      if (index != -1) {
        _posts[index] = updatedPost;
        state = AsyncValue.data(List<PostModel>.from(_posts));
      }
    } catch (e, stackTrace) {
      if (index != -1 && originalPost != null) {
        _posts[index] = originalPost;
        state = AsyncValue.data(List<PostModel>.from(_posts));
      }
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  void updateCommentsCount({
    required String postId,
    required int commentsCount,
  }) {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) {
      return;
    }

    _posts[index] = _posts[index].copyWith(commentsCount: commentsCount);
    state = AsyncValue.data(List<PostModel>.from(_posts));
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
