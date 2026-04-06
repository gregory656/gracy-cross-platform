import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/services/nairobi_timezone_service.dart';
import '../../../shared/utils/post_share_text.dart';
import '../providers/post_providers_fixed.dart';

class PostCardFixed extends ConsumerStatefulWidget {
  final PostModel post;

  const PostCardFixed({super.key, required this.post});

  @override
  ConsumerState<PostCardFixed> createState() => _PostCardFixedState();
}

class _PostCardFixedState extends ConsumerState<PostCardFixed> {
  bool _isLiking = false;

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

    setState(() {
      _isLiking = true;
    });

    try {
      await ref.read(postsProvider.notifier).toggleLike(widget.post.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${widget.post.isLikedByCurrentUser ? 'unlike' : 'like'} post',
            ),
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

  void _showCommentsComingSoon() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Comments are coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333), width: 1),
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
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: widget.post.authorAvatar != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: widget.post.authorAvatar!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const Icon(Icons.person, color: Colors.grey),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, color: Colors.grey),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.grey),
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(widget.post.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
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
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),

          // Image
          if (widget.post.imageUrl != null)
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
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 300,
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 48,
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
                  label: widget.post.commentsCount.toString(),
                  isActive: false,
                  isLoading: false,
                  onPressed: _showCommentsComingSoon,
                  activeColor: Colors.blue,
                ),
                const SizedBox(width: 24),

                // Share Button
                _EngagementButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  isActive: false,
                  isLoading: false,
                  onPressed: _sharePost,
                  activeColor: Colors.green,
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
