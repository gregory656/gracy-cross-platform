import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/elite_animations.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/nairobi_timezone_service.dart';
import '../../../shared/widgets/report_reason_sheet.dart';
import '../providers/post_providers.dart';

class PostCommentsBottomSheet extends ConsumerStatefulWidget {
  const PostCommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.initialCount,
    required this.onCountChanged,
  });

  final String postId;
  final String postAuthorId;
  final int initialCount;
  final ValueChanged<int> onCountChanged;

  @override
  ConsumerState<PostCommentsBottomSheet> createState() =>
      _PostCommentsBottomSheetState();
}

class _PostCommentsBottomSheetState
    extends ConsumerState<PostCommentsBottomSheet> {
  static const Uuid _uuid = Uuid();

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  List<PostCommentModel> _comments = <PostCommentModel>[];
  PostCommentModel? _replyTarget;
  PostCommentModel? _editingTarget;
  bool _isLoading = true;
  bool _isSubmitting = false;

  int get _visibleCommentCount => _comments.length;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final List<PostCommentModel> comments = await ref
          .read(optimizedPostServiceProvider)
          .getComments(widget.postId);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
      widget.onCountChanged(_visibleCommentCount);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load comments: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitComment() async {
    final String content = _commentController.text.trim();
    if (content.isEmpty || _isSubmitting) {
      return;
    }

    final currentUser = ref.read(resolvedCurrentUserProvider);
    final String tempId = 'temp-${_uuid.v4()}';
    final PostCommentModel optimisticComment = PostCommentModel(
      id: tempId,
      postId: widget.postId,
      authorId: currentUser?.id ?? '',
      parentId: _replyTarget?.id,
      content: content,
      createdAt: DateTime.now().toUtc(),
      userName: currentUser?.fullName ?? currentUser?.username ?? 'You',
      likesCount: 0,
      isPending: true,
    );

    setState(() {
      _isSubmitting = true;
      _comments = <PostCommentModel>[..._comments, optimisticComment];
      _commentController.clear();
      _replyTarget = null;
      _editingTarget = null;
    });
    widget.onCountChanged(_visibleCommentCount);

    try {
      final PostCommentModel savedComment = await ref
          .read(optimizedPostServiceProvider)
          .addComment(
            postId: widget.postId,
            content: content,
            parentId: optimisticComment.parentId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .map(
              (PostCommentModel comment) =>
                  comment.id == tempId ? savedComment : comment,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .where((PostCommentModel comment) => comment.id != tempId)
            .toList();
      });
      widget.onCountChanged(_visibleCommentCount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitEdit() async {
    final PostCommentModel? target = _editingTarget;
    final String content = _commentController.text.trim();
    if (target == null || content.isEmpty || _isSubmitting) {
      return;
    }

    final PostCommentModel original = target;
    setState(() {
      _isSubmitting = true;
      _comments = _comments
          .map(
            (PostCommentModel comment) => comment.id == target.id
                ? comment.copyWith(content: content, isPending: true)
                : comment,
          )
          .toList();
      _commentController.clear();
      _editingTarget = null;
      _replyTarget = null;
    });

    try {
      final PostCommentModel updatedComment = await ref
          .read(optimizedPostServiceProvider)
          .updateComment(commentId: target.id, content: content);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .map(
              (PostCommentModel comment) =>
                  comment.id == target.id ? updatedComment : comment,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .map(
              (PostCommentModel comment) =>
                  comment.id == original.id ? original : comment,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteComment(PostCommentModel comment) async {
    final List<String> idsToRemove = _descendantIds(comment.id);
    final List<PostCommentModel> previousComments = List<PostCommentModel>.from(
      _comments,
    );

    setState(() {
      _comments = _comments
          .where((PostCommentModel item) => !idsToRemove.contains(item.id))
          .toList();
    });
    widget.onCountChanged(_visibleCommentCount);

    try {
      await ref.read(optimizedPostServiceProvider).deleteComment(comment.id);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = previousComments;
      });
      widget.onCountChanged(_visibleCommentCount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _hideComment(PostCommentModel comment) async {
    final PostCommentModel original = comment;

    setState(() {
      _comments = _comments
          .map(
            (PostCommentModel item) => item.id == comment.id
                ? item.copyWith(isHidden: true, isPending: true)
                : item,
          )
          .toList();
    });

    try {
      final PostCommentModel hiddenComment = await ref
          .read(optimizedPostServiceProvider)
          .hideComment(comment.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .map(
              (PostCommentModel item) =>
                  item.id == comment.id ? hiddenComment : item,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .map(
              (PostCommentModel item) =>
                  item.id == original.id ? original : item,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to hide comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleCommentLike(PostCommentModel comment) async {
    final bool nextLiked = !comment.isLikedByCurrentUser;
    final int nextCount = nextLiked
        ? comment.likesCount + 1
        : (comment.likesCount > 0 ? comment.likesCount - 1 : 0);

    setState(() {
      _comments = _comments
          .map(
            (PostCommentModel item) => item.id == comment.id
                ? item.copyWith(
                    isLikedByCurrentUser: nextLiked,
                    likesCount: nextCount,
                  )
                : item,
          )
          .toList();
    });

    try {
      await ref
          .read(optimizedPostServiceProvider)
          .toggleCommentLike(comment.id);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .map(
              (PostCommentModel item) => item.id == comment.id ? comment : item,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmReportComment(PostCommentModel comment) async {
    final String? reason = await showReportReasonSheet(
      context,
      title: 'Report Comment',
      subtitle: 'Choose the reason that best matches this comment.',
    );

    if (reason == null || !mounted) {
      return;
    }

    final List<String> idsToHide = _descendantIds(comment.id);
    final List<PostCommentModel> previousComments = List<PostCommentModel>.from(
      _comments,
    );
    setState(() {
      _comments = _comments
          .where((PostCommentModel item) => !idsToHide.contains(item.id))
          .toList();
    });
    widget.onCountChanged(_visibleCommentCount);

    try {
      await ref
          .read(optimizedPostServiceProvider)
          .reportComment(commentId: comment.id, reason: reason);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Thank you. We've hidden this content and our team will review it shortly.",
          ),
          backgroundColor: AppColors.electricBlue,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = previousComments;
      });
      widget.onCountChanged(_visibleCommentCount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to report comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startReply(PostCommentModel comment) {
    setState(() {
      _replyTarget = comment;
      _editingTarget = null;
    });
    _commentFocusNode.requestFocus();
  }

  void _startEdit(PostCommentModel comment) {
    setState(() {
      _editingTarget = comment;
      _replyTarget = null;
      _commentController.text = comment.content;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
    _commentFocusNode.requestFocus();
  }

  void _clearComposerMode() {
    setState(() {
      _replyTarget = null;
      _editingTarget = null;
      _commentController.clear();
    });
  }

  Future<void> _showCommentActions(PostCommentModel comment) async {
    final String? currentUserId = ref.read(authNotifierProvider).userId;
    if (currentUserId == null) {
      return;
    }

    final bool isWriter = currentUserId == comment.authorId;
    final bool isPostOwner = currentUserId == widget.postAuthorId;

    EliteHaptics.mediumImpact();

    if (!isWriter && !isPostOwner) {
      await _showReportActions(comment);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _CommentModerationSheet(
        isWriter: isWriter,
        isPostOwner: isPostOwner,
        isHidden: comment.isHidden,
        onEdit: () {
          Navigator.of(context).pop();
          _startEdit(comment);
        },
        onHide: () {
          Navigator.of(context).pop();
          _hideComment(comment);
        },
        onDelete: () {
          Navigator.of(context).pop();
          _deleteComment(comment);
        },
      ),
    );
  }

  Future<void> _showReportActions(PostCommentModel comment) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _CommentReportSheet(
        onReport: () {
          Navigator.of(context).pop();
          _confirmReportComment(comment);
        },
      ),
    );
  }

  List<String> _descendantIds(String rootId) {
    final Set<String> ids = <String>{rootId};
    bool changed = true;
    while (changed) {
      changed = false;
      for (final PostCommentModel comment in _comments) {
        if (comment.parentId != null &&
            ids.contains(comment.parentId) &&
            ids.add(comment.id)) {
          changed = true;
        }
      }
    }
    return ids.toList();
  }

  List<PostCommentModel> _childrenOf(String? parentId) {
    final List<PostCommentModel> children =
        _comments
            .where((PostCommentModel comment) => comment.parentId == parentId)
            .toList()
          ..sort((PostCommentModel a, PostCommentModel b) {
            return a.createdAt.compareTo(b.createdAt);
          });
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<PostCommentModel> roots = _childrenOf(null);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Row(
              children: <Widget>[
                Text(
                  'Comments',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_visibleCommentCount',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : roots.isEmpty
                ? _EmptyCommentsState(theme: theme)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: roots.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _ThreadedCommentBranch(
                        comment: roots[index],
                        children: _childrenOf(roots[index].id),
                        allChildrenOf: _childrenOf,
                        onReply: _startReply,
                        onLike: _toggleCommentLike,
                        onReport: _confirmReportComment,
                        onFlag: _confirmReportComment,
                        onLongPress: _showCommentActions,
                      );
                    },
                  ),
          ),
          if (_replyTarget != null || _editingTarget != null)
            _ComposerBanner(
              label: _editingTarget != null
                  ? 'Editing your comment'
                  : 'Replying to ${_replyTarget?.userName ?? 'comment'}',
              onCancel: _clearComposerMode,
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (_editingTarget != null) {
                          _submitEdit();
                          return;
                        }
                        _submitComment();
                      },
                      decoration: InputDecoration(
                        hintText: _editingTarget != null
                            ? 'Edit your comment...'
                            : _replyTarget != null
                            ? 'Write a reply...'
                            : 'Add a comment...',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_editingTarget != null) {
                              _submitEdit();
                              return;
                            }
                            _submitComment();
                          },
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.electricBlue,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCommentsState extends StatelessWidget {
  const _EmptyCommentsState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.comment_bank_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Replies stay threaded so the discussion feels easy to follow.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerBanner extends StatelessWidget {
  const _ComposerBanner({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _ThreadedCommentBranch extends StatelessWidget {
  const _ThreadedCommentBranch({
    required this.comment,
    required this.children,
    required this.allChildrenOf,
    required this.onReply,
    required this.onLike,
    required this.onReport,
    required this.onFlag,
    required this.onLongPress,
  });

  final PostCommentModel comment;
  final List<PostCommentModel> children;
  final List<PostCommentModel> Function(String? parentId) allChildrenOf;
  final ValueChanged<PostCommentModel> onReply;
  final ValueChanged<PostCommentModel> onLike;
  final ValueChanged<PostCommentModel> onReport;
  final ValueChanged<PostCommentModel> onFlag;
  final ValueChanged<PostCommentModel> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _CommentItem(
          comment: comment,
          onReply: onReply,
          onLike: onLike,
          onReport: onReport,
          onFlag: onFlag,
          onLongPress: onLongPress,
        ),
        for (final PostCommentModel child in children)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 1,
                  margin: const EdgeInsets.only(right: 12),
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _ThreadedCommentBranch(
                    comment: child,
                    children: allChildrenOf(child.id),
                    allChildrenOf: allChildrenOf,
                    onReply: onReply,
                    onLike: onLike,
                    onReport: onReport,
                    onFlag: onFlag,
                    onLongPress: onLongPress,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.onReply,
    required this.onLike,
    required this.onReport,
    required this.onFlag,
    required this.onLongPress,
  });

  final PostCommentModel comment;
  final ValueChanged<PostCommentModel> onReply;
  final ValueChanged<PostCommentModel> onLike;
  final ValueChanged<PostCommentModel> onReport;
  final ValueChanged<PostCommentModel> onFlag;
  final ValueChanged<PostCommentModel> onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool disableInlineActions = comment.isPending || comment.isHidden;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: comment.isPending || comment.isHidden ? 0.5 : 1,
      child: GestureDetector(
        onLongPress: () => onLongPress(comment),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(17),
                ),
                child: comment.userAvatar != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: CachedNetworkImage(
                          imageUrl: comment.userAvatar!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 16,
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.grey, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          comment.userName ?? 'Unknown User',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _formatCommentTime(comment.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (comment.isPending)
                          Text(
                            'Sending...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.electricBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (comment.isHidden)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              'Hidden',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.content,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _CommentActionButton(
                          label: 'Reply',
                          onPressed: disableInlineActions
                              ? null
                              : () => onReply(comment),
                        ),
                        _CommentActionButton(
                          label: 'Like',
                          icon: comment.isLikedByCurrentUser
                              ? Icons.favorite
                              : Icons.favorite_border,
                          iconColor: comment.isLikedByCurrentUser
                              ? AppColors.electricBlue
                              : theme.colorScheme.onSurfaceVariant,
                          trailingText: comment.likesCount > 0
                              ? '${comment.likesCount}'
                              : null,
                          onPressed: disableInlineActions
                              ? null
                              : () => onLike(comment),
                        ),
                        _CommentActionButton(
                          label: 'Report',
                          onPressed: disableInlineActions
                              ? null
                              : () => onReport(comment),
                        ),
                        _CommentActionButton(
                          label: 'Flag',
                          textColor: AppColors.warning,
                          onPressed: disableInlineActions
                              ? null
                              : () => onFlag(comment),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCommentTime(DateTime timestamp) {
    final DateTime nairobiTime = NairobiTimezoneService.instance
        .convertToNairobi(timestamp);
    final DateTime now = NairobiTimezoneService.instance.now;
    final Duration difference = now.difference(nairobiTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}

class _CommentActionButton extends StatelessWidget {
  const _CommentActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconColor,
    this.textColor,
    this.trailingText,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color resolvedTextColor =
        textColor ?? theme.colorScheme.onSurfaceVariant;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: resolvedTextColor,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: iconColor ?? resolvedTextColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: resolvedTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailingText != null) ...<Widget>[
            const SizedBox(width: 4),
            Text(
              trailingText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: resolvedTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentModerationSheet extends StatelessWidget {
  const _CommentModerationSheet({
    required this.isWriter,
    required this.isPostOwner,
    required this.isHidden,
    required this.onEdit,
    required this.onHide,
    required this.onDelete,
  });

  final bool isWriter;
  final bool isPostOwner;
  final bool isHidden;
  final VoidCallback onEdit;
  final VoidCallback onHide;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _CommentSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isWriter)
              _ModerationActionTile(
                icon: Icons.edit_outlined,
                label: 'Edit Comment',
                onTap: onEdit,
              ),
            if (isPostOwner && !isWriter)
              _ModerationActionTile(
                icon: Icons.visibility_off_outlined,
                label: isHidden ? 'Comment Hidden' : 'Hide Comment',
                enabled: !isHidden,
                onTap: onHide,
              ),
            _ModerationActionTile(
              icon: Icons.delete_outline,
              label: 'Delete Comment',
              iconColor: const Color(0xFFFF3B30),
              textColor: const Color(0xFFFF3B30),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentReportSheet extends StatelessWidget {
  const _CommentReportSheet({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _CommentSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ModerationActionTile(
              icon: Icons.report_outlined,
              label: 'Report Comment',
              onTap: onReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentSheetFrame extends StatelessWidget {
  const _CommentSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ModerationActionTile extends StatelessWidget {
  const _ModerationActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? iconColor : Colors.white38),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: enabled ? textColor : Colors.white38,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
