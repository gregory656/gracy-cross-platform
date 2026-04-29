import 'package:equatable/equatable.dart';

import 'feed_category.dart';

class PostModel extends Equatable {
  final String id;
  final String authorId;
  final String? imageUrl;
  final String content;
  final int likesCount;
  final int commentsCount;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? authorName;
  final String? authorAvatar;
  final bool isLikedByCurrentUser;
  final bool likesVisible;

  /// Supabase `posts.category` slug (e.g. [FeedCategories.marketplace]).
  final String category;

  /// When true, UI shows anonymous identity (Silent Confessions).
  final bool isAnonymous;

  /// Structured fields per category (marketplace, housing, projects, etc.).
  final Map<String, dynamic>? extra;

  const PostModel({
    required this.id,
    required this.authorId,
    this.imageUrl,
    this.content = '',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.authorName,
    this.authorAvatar,
    this.isLikedByCurrentUser = false,
    this.likesVisible = true,
    this.category = FeedCategories.discussions,
    this.isAnonymous = false,
    this.extra,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawContent =
        map['content'] ??
        map['text'] ??
        map['caption'] ??
        map['body'] ??
        map['post_text'] ??
        map['description'] ??
        map['message'];

    final Map<String, dynamic>? extraMap = _parseExtra(map['extra']);

    return PostModel(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      imageUrl: map['image_url'] as String?,
      content: rawContent?.toString() ?? '',
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (map['comments_count'] as num?)?.toInt() ?? 0,
      viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      authorName: (map['is_anonymous'] as bool? ?? false) 
        ? null 
        : (map['author_name'] as String?),
      authorAvatar: (map['is_anonymous'] as bool? ?? false) 
        ? null 
        : (map['author_avatar'] as String?),
      isLikedByCurrentUser: (map['is_liked_by_current_user'] as bool?) ?? false,
      likesVisible: (map['likes_visible'] as bool?) ?? true,
      category: map['category'] as String? ?? FeedCategories.discussions,
      isAnonymous: (map['is_anonymous'] as bool?) ?? false,
      extra: extraMap,
    );
  }

  static Map<String, dynamic>? _parseExtra(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_id': authorId,
      'image_url': imageUrl,
      'content': content,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'view_count': viewCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'likes_visible': likesVisible,
      'category': category,
      'is_anonymous': isAnonymous,
      'extra': extra,
    };
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? imageUrl,
    String? content,
    int? likesCount,
    int? commentsCount,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorName,
    String? authorAvatar,
    bool? isLikedByCurrentUser,
    bool? likesVisible,
    String? category,
    bool? isAnonymous,
    Map<String, dynamic>? extra,
  }) {
    final bool resolvedAnonymous = isAnonymous ?? this.isAnonymous;
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      imageUrl: imageUrl ?? this.imageUrl,
      content: content ?? this.content,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorName: resolvedAnonymous ? null : (authorName ?? this.authorName),
      authorAvatar:
          resolvedAnonymous ? null : (authorAvatar ?? this.authorAvatar),
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      likesVisible: likesVisible ?? this.likesVisible,
      category: category ?? this.category,
      isAnonymous: resolvedAnonymous,
      extra: extra ?? this.extra,
    );
  }

  /// Hashtag-style label for the global "All" feed.
  String get categoryFeedTag => feedCategoryTagForSlug(category);

  /// Marketplace price label from [extra], if present.
  String? get marketplacePriceLabel {
    if (category != FeedCategories.marketplace) {
      return null;
    }
    final dynamic p = extra?['price'];
    if (p == null) {
      return null;
    }
    final String s = p.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool get isProjectsCategory => category == FeedCategories.projects;

  String get optimizedImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return '';
    if (imageUrl!.contains('cloudinary.com')) {
      return '$imageUrl?q_auto,f_auto,w_1080';
    }
    // High-resolution view modifier for flagship experience as requested
    return '$imageUrl?width=1000&quality=90';
  }

  @override
  List<Object?> get props => [
    id,
    authorId,
    imageUrl,
    content,
    likesCount,
    commentsCount,
    viewCount,
    createdAt,
    updatedAt,
    authorName,
    authorAvatar,
    isLikedByCurrentUser,
    likesVisible,
    category,
    isAnonymous,
    extra,
  ];
}

class PostCommentModel extends Equatable {
  final String id;
  final String postId;
  final String authorId;
  final String? parentId;
  final String content;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;
  final int likesCount;
  final bool isLikedByCurrentUser;
  final bool isHidden;
  final bool isPending;

  const PostCommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    this.parentId,
    required this.content,
    required this.createdAt,
    this.userName,
    this.userAvatar,
    this.likesCount = 0,
    this.isLikedByCurrentUser = false,
    this.isHidden = false,
    this.isPending = false,
  });

  factory PostCommentModel.fromMap(Map<String, dynamic> map) {
    return PostCommentModel(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      authorId: (map['author_id'] ?? map['user_id']) as String,
      parentId: map['parent_id'] as String?,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      userName: map['user_name'] as String?,
      userAvatar: map['user_avatar'] as String?,
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      isLikedByCurrentUser: (map['is_liked_by_current_user'] as bool?) ?? false,
      isHidden: (map['is_hidden'] as bool?) ?? false,
      isPending: (map['is_pending'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'parent_id': parentId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'likes_count': likesCount,
      'is_liked_by_current_user': isLikedByCurrentUser,
      'is_hidden': isHidden,
      'is_pending': isPending,
    };
  }

  PostCommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? parentId,
    bool clearParentId = false,
    String? content,
    DateTime? createdAt,
    String? userName,
    String? userAvatar,
    int? likesCount,
    bool? isLikedByCurrentUser,
    bool? isHidden,
    bool? isPending,
  }) {
    return PostCommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      likesCount: likesCount ?? this.likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isHidden: isHidden ?? this.isHidden,
      isPending: isPending ?? this.isPending,
    );
  }

  @override
  List<Object?> get props => [
    id,
    postId,
    authorId,
    parentId,
    content,
    createdAt,
    userName,
    userAvatar,
    likesCount,
    isLikedByCurrentUser,
    isHidden,
    isPending,
  ];
}
