import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/chat/data/chat_repository.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/services/timezone_service.dart';
import 'gracy_ai_logo.dart';

class GlassmorphismBubble extends StatefulWidget {
  GlassmorphismBubble({
    required this.message,
    required this.onReply,
    required this.onForward,
    required this.onDelete,
  }) : super(key: ValueKey(message.id));

  final MessageModel message;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  @override
  State<GlassmorphismBubble> createState() => _GlassmorphismBubbleState();
}

class _GlassmorphismBubbleState extends State<GlassmorphismBubble>
    with SingleTickerProviderStateMixin {
  static const Color _electricBlue = Color(0xFF007AFF);
  static const Color _glassDark = Color(0xFF1A1D29);

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
    _copyMessage();
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

  @override
  Widget build(BuildContext context) {
    final bool isMe = widget.message.isMe;
    final bool isAiMessage =
        !isMe && ChatRepository.isBotParticipant(widget.message.senderId);
    final Alignment bubbleAlignment = isMe
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final MainAxisAlignment rowAlignment = isMe
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;
    final CrossAxisAlignment contentAlignment = isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final Color bubbleColor = isMe
        ? _electricBlue
        : _glassDark.withValues(alpha: 0.92);
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMe ? 22 : 8),
      bottomRight: Radius.circular(isMe ? 8 : 22),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 14),
      alignment: bubbleAlignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: rowAlignment,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && isAiMessage)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: const GracyAILogo(size: 28, glowing: true),
            ),
          Flexible(
            child: GestureDetector(
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
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: borderRadius,
                        border: isMe
                            ? null
                            : Border.all(
                                color: _electricBlue.withValues(alpha: 0.28),
                                width: 1,
                              ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: isMe
                                ? _electricBlue.withValues(alpha: 0.22)
                                : _electricBlue.withValues(alpha: 0.12),
                            blurRadius: isMe ? 10 : 12,
                            spreadRadius: isMe ? 0 : 1,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: contentAlignment,
                        children: [
                          Text(
                            widget.message.text,
                            softWrap: true,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.94),
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
                                      color: Colors.white.withValues(alpha: 0.64),
                                      fontSize: 11,
                                    ),
                              ),
                              if (isAiMessage) ...<Widget>[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _electricBlue.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'AI',
                                    style: Theme.of(context).textTheme.labelSmall
                                        ?.copyWith(
                                          color: _electricBlue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                  ),
                                ),
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
          ),
        ],
      ),
    );
  }
}
