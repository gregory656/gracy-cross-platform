import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/router/shell_ui_provider.dart';
import '../../../core/utils/elite_animations.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/nairobi_timezone_service.dart';
import '../../../shared/utils/post_share_text.dart';
import '../../../shared/widgets/report_reason_sheet.dart';
import 'post_comments_bottom_sheet.dart';
import '../providers/post_providers.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final Future<void> Function()? onPostChanged;
  final VoidCallback? onPostDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.onPostChanged,
    this.onPostDeleted,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isLiking = false;
  bool _isDeleting = false;
  bool _isSavingImage = false;
  bool _isHiddenByReport = false;
  final ValueNotifier<bool> _isSavingImageNotifier = ValueNotifier(false);
  late int _displayedCommentCount;

  @override
  void initState() {
    super.initState();
    _displayedCommentCount = widget.post.commentsCount;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.commentsCount != widget.post.commentsCount) {
      _displayedCommentCount = widget.post.commentsCount;
    }
  }

  @override
  void dispose() {
    _isSavingImageNotifier.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final nairobiTime = NairobiTimezoneService.instance.convertToNairobi(
      timestamp,
    );
    final now = NairobiTimezoneService.instance.now;
    final difference = now.difference(nairobiTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(nairobiTime);
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    final isCurrentlyLiked = widget.post.isLikedByCurrentUser;
    final actionLabel = widget.post.isLikedByCurrentUser ? 'unlike' : 'like';

    if (isCurrentlyLiked) {
      EliteHaptics.lightImpact();
    } else {
      EliteHaptics.mediumImpact();
    }

    setState(() {
      _isLiking = true;
    });

    try {
      await ref.read(postsProvider.notifier).toggleLike(widget.post.id);
      if (widget.onPostChanged != null) {
        await widget.onPostChanged!.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to $actionLabel post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  void _sharePost() {
    SharePlus.instance.share(
      ShareParams(text: buildPostShareText(widget.post)),
    );
  }

  Future<void> _showComments() async {
    ref.read(shellNavigationVisibleProvider.notifier).hide();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PostCommentsBottomSheet(
          postId: widget.post.id,
          initialCount: _displayedCommentCount,
          onCountChanged: (int count) {
            if (!mounted) {
              return;
            }
            setState(() {
              _displayedCommentCount = count;
            });
          },
        ),
      );
    } finally {
      ref.read(shellNavigationVisibleProvider.notifier).show();
    }
  }

  bool _isOwnedByCurrentUser(String? currentUserId) {
    return currentUserId != null && currentUserId == widget.post.authorId;
  }

  bool get _hasSavableMedia => widget.post.imageUrl?.isNotEmpty == true;

  Future<void> _showPostActions(bool canManagePost) async {
    final bool canReportPost = !canManagePost;
    if (_isDeleting || (!canManagePost && !_hasSavableMedia && !canReportPost)) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PostActionSheet(
        canManagePost: canManagePost,
        canSaveToGallery: _hasSavableMedia,
        isSavingImageListenable: _isSavingImageNotifier,
        onEdit: () async {
          Navigator.of(sheetContext).pop();
          await _showEditPostSheet();
        },
        onDelete: () async {
          Navigator.of(sheetContext).pop();
          await _confirmDeletePost();
        },
        onSaveToGallery: _saveToGallery,
        canReportPost: canReportPost,
        onReport: () async {
          Navigator.of(sheetContext).pop();
          await _reportPost();
        },
      ),
    );
  }

  Future<void> _reportPost() async {
    final String? reason = await showReportReasonSheet(
      context,
      title: 'Report Post',
      subtitle: 'Choose the reason that best matches this post.',
    );

    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      _isHiddenByReport = true;
    });

    try {
      await ref.read(optimizedPostServiceProvider).reportPost(
            postId: widget.post.id,
            reason: reason,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Thank you. We've hidden this content and our team will review it shortly.",
          ),
          backgroundColor: Color(0xFF007AFF),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isHiddenByReport = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to report post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditPostSheet() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final wasUpdated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPostSheet(post: widget.post),
    );

    if (wasUpdated == true) {
      if (widget.onPostChanged != null) {
        await widget.onPostChanged!.call();
      }
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Post updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _confirmDeletePost() async {
    EliteHaptics.mediumImpact();

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeletePostDialog(),
    );

    if (shouldDelete == true) {
      await _deletePost();
    }
  }

  Future<void> _deletePost() async {
    if (_isDeleting) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);

    if (mounted) {
      setState(() {
        _isDeleting = true;
      });
    }

    try {
      await ref.read(postsProvider.notifier).deletePost(widget.post.id);
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Post deleted'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onPostDeleted?.call();
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Failed to delete post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSavingImage || !_hasSavableMedia) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() {
      _isSavingImage = true;
    });
    _isSavingImageNotifier.value = true;

    try {
      final permissionGranted = await _requestGalleryPermission();
      if (!permissionGranted) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Gallery permission is required to save this post'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final dio = Dio();
      final response = await dio.get(
        widget.post.optimizedImageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(List<int>.from(response.data as List));

      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: _buildGalleryFileName(),
      );
      final isSuccess =
          result is Map &&
          (result['isSuccess'] == true || result['success'] == true);

      if (isSuccess) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Post saved to gallery!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Failed to save to gallery'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingImage = false;
        });
      }
      _isSavingImageNotifier.value = false;
    }
  }

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted || status.isLimited;
    }

    if (Platform.isAndroid) {
      // The Android plugin writes through MediaStore, so modern Android
      // versions do not need a runtime storage prompt for this save flow.
      return true;
    }

    return true;
  }

  String _buildGalleryFileName() {
    final createdAt = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(widget.post.createdAt);
    return 'gracy_post_$createdAt';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(
      authNotifierProvider.select((authState) => authState.userId),
    );
    final canManagePost = _isOwnedByCurrentUser(currentUserId);

    if (_isHiddenByReport) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerTheme.color ?? const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child:
                      widget.post.authorAvatar != null &&
                          widget.post.authorAvatar!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: widget.post.authorAvatar!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Icon(
                              Icons.person,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 12),
                // Author info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName ?? 'Unknown User',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(widget.post.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManagePost || _hasSavableMedia || !canManagePost)
                  IconButton(
                    onPressed: () => _showPostActions(canManagePost),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      Icons.more_horiz,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),

          // Content
          if (widget.post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.post.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),

          // Image
          if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.post.optimizedImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 300,
                  placeholder: (context, url) => Container(
                    height: 300,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 300,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image unavailable',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Engagement Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Like Button
                _EngagementButton(
                  icon: widget.post.isLikedByCurrentUser
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: widget.post.likesCount.toString(),
                  isActive: widget.post.isLikedByCurrentUser,
                  isLoading: _isLiking,
                  onPressed: _toggleLike,
                  activeColor: Colors.red,
                ),
                const SizedBox(width: 24),

                // Comment Button
                _EngagementButton(
                  icon: Icons.comment_outlined,
                  label: _displayedCommentCount.toString(),
                  isActive: false,
                  isLoading: false,
                  onPressed: _showComments,
                  activeColor: theme.colorScheme.primary,
                ),
                const SizedBox(width: 24),

                // Share Button
                _EngagementButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  isActive: false,
                  isLoading: false,
                  onPressed: _sharePost,
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onPressed;
  final Color activeColor;

  const _EngagementButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isLoading,
    required this.onPressed,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isActive ? activeColor : Colors.grey[400]!,
                    ),
                  ),
                )
              : Icon(
                  icon,
                  size: 20,
                  color: isActive ? activeColor : Colors.grey[400],
                ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.grey[400],
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostActionSheet extends StatelessWidget {
  const _PostActionSheet({
    required this.canManagePost,
    required this.canSaveToGallery,
    required this.canReportPost,
    required this.isSavingImageListenable,
    required this.onEdit,
    required this.onDelete,
    required this.onSaveToGallery,
    required this.onReport,
  });

  static const Color _sheetColor = Color(0xFF1A1A1A);
  static const Color _borderColor = Color(0xFF333333);
  static const Color _deleteColor = Color(0xFFFF3B30);
  final bool canManagePost;
  final bool canSaveToGallery;
  final bool canReportPost;
  final ValueListenable<bool> isSavingImageListenable;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function() onSaveToGallery;
  final Future<void> Function() onReport;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, viewPadding.bottom + 12),
        child: Material(
          color: _sheetColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Post Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (canSaveToGallery) ...[
                ValueListenableBuilder<bool>(
                  valueListenable: isSavingImageListenable,
                  builder: (context, isSavingImage, _) {
                    return _ActionTile(
                      icon: Icons.download_outlined,
                      label: 'Save to Gallery',
                      color: Colors.white,
                      isLoading: isSavingImage,
                      onTap: isSavingImage ? null : onSaveToGallery,
                    );
                  },
                ),
              ],
              if ((canSaveToGallery && canManagePost) ||
                  (canSaveToGallery && canReportPost))
                const Divider(height: 1, color: _borderColor),
              if (canReportPost) ...[
                _ActionTile(
                  icon: Icons.outlined_flag_rounded,
                  label: 'Report Post',
                  color: Colors.white,
                  onTap: onReport,
                ),
                if (canManagePost) const Divider(height: 1, color: _borderColor),
              ],
              if (canManagePost) ...[
                _ActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit Post',
                  color: Colors.white,
                  onTap: onEdit,
                ),
                const Divider(height: 1, color: _borderColor),
                _ActionTile(
                  icon: Icons.delete_outline,
                  label: 'Delete Post',
                  color: _deleteColor,
                  onTap: onDelete,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function()? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null
          ? null
          : () async {
              await onTap!.call();
            },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPostSheet extends ConsumerStatefulWidget {
  const _EditPostSheet({required this.post});

  final PostModel post;

  @override
  ConsumerState<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<_EditPostSheet> {
  static const Color _sheetColor = Color(0xFF1A1A1A);
  static const Color _panelColor = Color(0xFF0E0E0E);
  static const Color _borderColor = Color(0xFF333333);
  final TextEditingController _captionController = TextEditingController();
  bool _isSaving = false;

  bool get _hasImage => widget.post.imageUrl?.isNotEmpty == true;

  bool get _canSave {
    if (_isSaving) {
      return false;
    }

    final trimmedCaption = _captionController.text.trim();
    final originalCaption = widget.post.content.trim();

    if (trimmedCaption == originalCaption) {
      return false;
    }

    if (trimmedCaption.isEmpty && !_hasImage) {
      return false;
    }

    return true;
  }

  @override
  void initState() {
    super.initState();
    _captionController.text = widget.post.content;
    _captionController.addListener(_handleCaptionChanged);
  }

  @override
  void dispose() {
    _captionController
      ..removeListener(_handleCaptionChanged)
      ..dispose();
    super.dispose();
  }

  void _handleCaptionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveChanges() async {
    if (!_canSave) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(postsProvider.notifier)
          .updatePostCaption(
            postId: widget.post.id,
            content: _captionController.text,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_buildEditErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildEditErrorMessage(Object error) {
    final raw = error.toString();
    const prefix = 'Exception: Failed to update post: ';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: _sheetColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              mediaQuery.viewPadding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Edit Post',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                Text(
                  'Update your caption and keep the post looking sharp in the feed.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                if (_hasImage) ...[
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _panelColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: widget.post.optimizedImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  'Caption',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _captionController,
                  enabled: !_isSaving,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 6,
                  minLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Refine your caption...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: _panelColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white70),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _borderColor),
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canSave ? _saveChanges : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white24,
                          disabledForegroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletePostDialog extends StatelessWidget {
  const _DeletePostDialog();

  static const Color _dialogColor = Color(0xFF1A1A1A);
  static const Color _borderColor = Color(0xFF333333);
  static const Color _deleteColor = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: _dialogColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete Post?',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This will permanently remove the post and its related activity. This action cannot be undone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _borderColor),
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deleteColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final String postId;

  const CommentsBottomSheet({super.key, required this.postId});

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF333333)),

          // Comments List
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.comment_outlined,
                    color: Colors.grey[400],
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comments coming soon!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Comment feature will be available in the next update.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF333333))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF333333)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF333333)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF444444)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSubmitting ? null : _submitComment,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentItem extends StatelessWidget {
  final PostCommentModel comment;

  const CommentItem({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(16),
            ),
            child: comment.userAvatar != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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

          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and time
                Row(
                  children: [
                    Text(
                      comment.userName ?? 'Unknown User',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatCommentTime(comment.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommentTime(DateTime timestamp) {
    final nairobiTime = NairobiTimezoneService.instance.convertToNairobi(
      timestamp,
    );
    final now = NairobiTimezoneService.instance.now;
    final difference = now.difference(nairobiTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
