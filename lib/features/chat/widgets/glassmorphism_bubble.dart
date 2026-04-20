import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/message_model.dart';
import '../../../shared/services/timezone_service.dart';
import 'gracy_ai_logo.dart';

class GlassmorphismBubble extends StatefulWidget {
  const GlassmorphismBubble({
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // GracyAI logo with neural glow
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: GracyAILogo(
              size: 28,
              glowing: true,
            ),
          ),
          // Glassmorphism bubble
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
                      color: _glassDark.withAlpha(204),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(22),
                      ),
                      border: Border.all(
                        color: _electricBlue.withAlpha(76),
                        width: 1,
                      ),
                      boxShadow: [
                        // Outer glow
                        BoxShadow(
                          color: _electricBlue.withAlpha(51),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                        // Inner shadow for depth
                        BoxShadow(
                          color: Colors.black.withAlpha(76),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(22),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Message content
                            Text(
                              widget.message.text,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withAlpha(230),
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
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withAlpha(153),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _electricBlue.withAlpha(51),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'AI',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: _electricBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
