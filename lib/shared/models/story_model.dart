import 'package:equatable/equatable.dart';

enum StoryViewStatus { unviewed, viewed, expired }

class StoryModel extends Equatable {
  const StoryModel({
    required this.id,
    required this.userId,
    this.content,
    this.imageUrl,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
    required this.authorName,
    required this.authorAvatar,
    this.isViewedByMe = false,
  });

  final String id;
  final String userId;
  final String? content;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;
  final String authorName;
  final String? authorAvatar;
  final bool isViewedByMe;

  bool get isActive => expiresAt.isAfter(DateTime.now());
  bool get isExpired => !isActive;
  StoryViewStatus get viewStatus {
    if (!isActive) return StoryViewStatus.expired;
    if (isViewedByMe) return StoryViewStatus.viewed;
    return StoryViewStatus.unviewed;
  }

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String?,
      imageUrl: map['image_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      viewedBy: (map['viewed_by'] as List?)?.cast<String>() ?? const [],
      authorName: map['author_name'] ?? 'Anonymous',
      authorAvatar: map['author_avatar'] as String?,
      isViewedByMe: false, // Computed client-side
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'viewed_by': viewedBy,
    };
  }

  StoryModel copyWith({
    String? id,
    String? userId,
    String? content,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? expiresAt,
    List<String>? viewedBy,
    String? authorName,
    String? authorAvatar,
    bool? isViewedByMe,
  }) {
    return StoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewedBy: viewedBy ?? this.viewedBy,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      isViewedByMe: isViewedByMe ?? this.isViewedByMe,
    );
  }

  @override
  List<Object?> get props => [
    id, userId, content, imageUrl, createdAt, expiresAt, viewedBy,
    authorName, authorAvatar, isViewedByMe,
  ];
}

