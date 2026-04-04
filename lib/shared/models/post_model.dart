import 'package:equatable/equatable.dart';

class PostModel extends Equatable {
  final String id;
  final String authorId;
  final String? imageUrl;
  final String content;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? authorName;
  final String? authorAvatar;
  final bool isLikedByCurrentUser;

  const PostModel({
    required this.id,
    required this.authorId,
    this.imageUrl,
    this.content = '',
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.authorName,
    this.authorAvatar,
    this.isLikedByCurrentUser = false,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      imageUrl: map['image_url'] as String?,
      content: map['content'] as String? ?? '',
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (map['comments_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : null,
      authorName: map['author_name'] as String?,
      authorAvatar: map['author_avatar'] as String?,
      isLikedByCurrentUser: (map['is_liked_by_current_user'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_id': authorId,
      'image_url': imageUrl,
      'content': content,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? imageUrl,
    String? content,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorName,
    String? authorAvatar,
    bool? isLikedByCurrentUser,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      imageUrl: imageUrl ?? this.imageUrl,
      content: content ?? this.content,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }

  String get optimizedImageUrl {
    if (imageUrl == null) return '';
    if (imageUrl!.contains('cloudinary.com')) {
      return '$imageUrl?q_auto,f_auto,w_1080';
    }
    return imageUrl!;
  }

  @override
  List<Object?> get props => [
        id,
        authorId,
        imageUrl,
        content,
        likesCount,
        commentsCount,
        createdAt,
        updatedAt,
        authorName,
        authorAvatar,
        isLikedByCurrentUser,
      ];
}

class PostCommentModel extends Equatable {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;

  const PostCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.userName,
    this.userAvatar,
  });

  factory PostCommentModel.fromMap(Map<String, dynamic> map) {
    return PostCommentModel(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      userName: map['user_name'] as String?,
      userAvatar: map['user_avatar'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        postId,
        userId,
        content,
        createdAt,
        userName,
        userAvatar,
      ];
}
