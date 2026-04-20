import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import 'post_service.dart';

class OptimizedPostService {
  static final OptimizedPostService _instance = OptimizedPostService._internal();
  factory OptimizedPostService() => _instance;
  OptimizedPostService._internal() : _postService = PostService();

  final PostService _postService;

  Future<PostModel> getPostById(String id) => _postService.getPostById(id);

  Future<List<PostModel>> getPosts({
    int limit = 20,
    int offset = 0,
    String? categoryFilter,
  }) async {
    final List<PostModel> posts = await _postService.getPosts(limit: limit, offset: offset);
    if (categoryFilter == null) {
      return posts;
    }
    return posts.where((PostModel post) => post.category == categoryFilter).toList(growable: false);
  }

  Future<List<PostModel>> getPostsByAuthor(String authorId) async {
    final List<PostModel> posts = await getPosts(limit: 100);
    return posts.where((PostModel post) => post.authorId == authorId).toList(growable: false);
  }

  Future<int> getTotalReach(String authorId) async {
    final List<PostModel> posts = await getPostsByAuthor(authorId);
    return posts.fold<int>(0, (int total, PostModel post) => total + post.viewCount);
  }

  Future<PostModel> createPost({
    required String content,
    File? imageFile,
    String category = 'discussions',
    bool isAnonymous = false,
    Map<String, dynamic>? extra,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);
    final PostModel post = await _postService.createPost(content: content, imageFile: imageFile);
    onProgress?.call(1.0);
    return post.copyWith(category: category, isAnonymous: isAnonymous, extra: extra);
  }

  Future<PostModel> toggleLike(String postId) => _postService.toggleLike(postId);

  Future<void> incrementViewsCount(String postId) => _postService.incrementViewsCount(postId);

  Future<void> deletePost(String postId) async {
    await _postService.deletePost(postId);
  }

  Future<PostModel> updatePostCaption({
    required String postId,
    required String content,
  }) async => _postService.updatePostCaption(postId: postId, content: content);

  Future<PostModel> setLikesVisibility({
    required String postId,
    required bool isVisible,
  }) async => _postService.setLikesVisibility(postId: postId, isVisible: isVisible);

  Future<File?> pickImage() => _postService.pickImage();

  Future<File?> compressSelectedImage(File? image) async {
    return image;
  }

  Future<String?> uploadProfileImage(File image) async => image.path;

  Future<PostModel> createPostWithImageUrl({
    required String content,
    required String imageUrl,
  }) async => PostModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        authorId: 'local',
        imageUrl: imageUrl,
        content: content,
        createdAt: DateTime.now(),
      );

  Future<void> reportPost({
    required String postId,
    required String reason,
  }) => _postService.reportPost(postId: postId, reason: reason);

  Future<List<PostCommentModel>> getComments(String postId) => _postService.getComments(postId);

  Future<PostCommentModel> addComment({
    required String postId,
    required String content,
    String? parentId,
  }) => _postService.addComment(postId: postId, content: content, parentId: parentId);

  Future<PostCommentModel> updateComment({
    required String commentId,
    required String content,
  }) => _postService.updateComment(commentId: commentId, content: content);

  Future<void> deleteComment(String commentId) => _postService.deleteComment(commentId);

  Future<PostCommentModel> hideComment(String commentId) => _postService.hideComment(commentId);

  Future<bool> toggleCommentLike(String commentId) => _postService.toggleCommentLike(commentId);

  Future<void> reportComment({
    required String commentId,
    required String reason,
  }) => _postService.reportComment(commentId: commentId, reason: reason);
}

final optimizedPostServiceProvider = Provider<OptimizedPostService>((ref) => OptimizedPostService());

