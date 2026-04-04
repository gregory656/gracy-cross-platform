import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/services/post_service.dart';

final postServiceProvider = Provider<PostService>((ref) {
  return PostService();
});

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<PostModel>>(
  () => PostsNotifier(),
);

class PostsNotifier extends AsyncNotifier<List<PostModel>> {
  late final PostService _postService;
  final List<PostModel> _posts = [];
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  @override
  Future<List<PostModel>> build() async {
    _postService = ref.read(postServiceProvider);
    await _loadPosts();
    return _posts;
  }

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

  Future<void> createPost({
    required String content,
  }) async {
    try {
      final newPost = await _postService.createPost(
        content: content,
      );

      _posts.insert(0, newPost);
      state = AsyncValue.data(List.from(_posts));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> toggleLike(String postId) async {
    try {
      final updatedPost = await _postService.toggleLike(postId);
      
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        _posts[index] = updatedPost;
        state = AsyncValue.data(List.from(_posts));
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _postService.deletePost(postId);
      
      _posts.removeWhere((post) => post.id == postId);
      state = AsyncValue.data(List.from(_posts));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
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
