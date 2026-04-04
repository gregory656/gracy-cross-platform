import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/message_model.dart';
import '../../../shared/services/timezone_service.dart';

class IndustrialMessageBubble extends StatefulWidget {
  const IndustrialMessageBubble({
    super.key,
    required this.message,
    required this.onReply,
    required this.onForward,
    required this.onDelete,
  });

  final MessageModel message;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  @override
  State<IndustrialMessageBubble> createState() => _IndustrialMessageBubbleState();
}

class _IndustrialMessageBubbleState extends State<IndustrialMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showContextMenu() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MessageActionSheet(
        message: widget.message,
        onReply: () {
          Navigator.pop(context);
          widget.onReply();
        },
        onCopy: () {
          Navigator.pop(context);
          _copyMessage();
        },
        onForward: () {
          Navigator.pop(context);
          widget.onForward();
        },
        onDelete: () {
          Navigator.pop(context);
          widget.onDelete();
        },
      ),
    );
  }

  void _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: widget.message.text));
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildStatusTicks() {
    final Color tickColor = switch (widget.message.status) {
      MessageStatus.sent => Colors.grey.shade600,
      MessageStatus.delivered => Colors.grey.shade600,
      MessageStatus.read => Colors.cyan,
    };

    final IconData firstTick = switch (widget.message.status) {
      MessageStatus.sent => Icons.check,
      MessageStatus.delivered => Icons.check,
      MessageStatus.read => Icons.check,
    };

    final IconData? secondTick = switch (widget.message.status) {
      MessageStatus.sent => null,
      MessageStatus.delivered => Icons.check,
      MessageStatus.read => Icons.check,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          firstTick,
          size: 14,
          color: tickColor,
        ),
        if (secondTick != null) ...[
          const SizedBox(width: 2),
          Icon(
            secondTick,
            size: 14,
            color: tickColor,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isMe;
    final bubbleColor = isMe 
        ? const Color(0xFF1E1E1E) 
        : const Color(0xFF262626);
    
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 18),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          GestureDetector(
            onLongPress: _showContextMenu,
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.grey.shade800,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: alignment,
                      children: [
                        Text(
                          widget.message.text,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              TimezoneService.formatNairobiTime(widget.message.sentAt),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              _buildStatusTicks(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet({
    required this.message,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onDelete,
  });

  final MessageModel message;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActionItem(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onTap: onReply,
                ),
                const SizedBox(height: 4),
                _buildActionItem(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: onCopy,
                ),
                const SizedBox(height: 4),
                _buildActionItem(
                  icon: Icons.forward_rounded,
                  label: 'Forward',
                  onTap: onForward,
                ),
                const SizedBox(height: 4),
                _buildActionItem(
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  onTap: onDelete,
                  isDestructive: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red.shade400 : Colors.grey.shade300,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red.shade400 : Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
