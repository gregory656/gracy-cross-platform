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
  State<IndustrialMessageBubble> createState() =>
      _IndustrialMessageBubbleState();
}

class _IndustrialMessageBubbleState extends State<IndustrialMessageBubble>
    with SingleTickerProviderStateMixin {
  static const Color _electricBlue = Color(0xFF007AFF);

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
      MessageStatus.read => _electricBlue,
    };
    final IconData statusIcon = widget.message.status == MessageStatus.sent
        ? Icons.done_rounded
        : Icons.done_all_rounded;

    return Icon(statusIcon, size: 14, color: tickColor);
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isMe;
    final bubbleColor = isMe ? _electricBlue : const Color(0xFF111318);
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final mainAxisAlignment = isMe
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 14),
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Transform.translate(
              offset: const Offset(4, 0),
              child: _BubbleTail(color: bubbleColor, isMe: false),
            ),
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
                      maxWidth: MediaQuery.of(context).size.width * 0.74,
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 14, 8),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22),
                        topRight: const Radius.circular(22),
                        bottomLeft: Radius.circular(isMe ? 22 : 8),
                        bottomRight: Radius.circular(isMe ? 8 : 22),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: alignment,
                      children: [
                        Text(
                          widget.message.text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 15.5,
                                height: 1.42,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              TimezoneService.formatNairobiTime(
                                widget.message.sentAt,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.74)
                                        : Colors.white54,
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
          if (isMe)
            Transform.translate(
              offset: const Offset(-4, 0),
              child: _BubbleTail(color: bubbleColor, isMe: true),
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

class _BubbleTail extends StatelessWidget {
  const _BubbleTail({required this.color, required this.isMe});

  final Color color;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(10, 12),
      painter: _BubbleTailPainter(color: color, isMe: isMe),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color, required this.isMe});

  final Color color;
  final bool isMe;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    if (isMe) {
      path
        ..moveTo(0, 0)
        ..quadraticBezierTo(
          size.width * 0.35,
          size.height * 0.15,
          size.width,
          2,
        )
        ..lineTo(size.width * 0.42, size.height)
        ..quadraticBezierTo(size.width * 0.28, size.height * 0.66, 0, 0);
    } else {
      path
        ..moveTo(size.width, 0)
        ..quadraticBezierTo(size.width * 0.65, size.height * 0.15, 0, 2)
        ..lineTo(size.width * 0.58, size.height)
        ..quadraticBezierTo(
          size.width * 0.72,
          size.height * 0.66,
          size.width,
          0,
        );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isMe != isMe;
  }
}
