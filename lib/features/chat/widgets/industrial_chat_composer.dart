import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IndustrialChatComposer extends StatefulWidget {
  const IndustrialChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.replyToMessage,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String? replyToMessage;
  final VoidCallback? onCancelReply;

  @override
  State<IndustrialChatComposer> createState() => _IndustrialChatComposerState();
}

class _IndustrialChatComposerState extends State<IndustrialChatComposer> {
  bool _isEmpty = true;

  void _showComingSoonMessage() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Media attachments unavailable for now.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final isEmpty = widget.controller.text.trim().isEmpty;
    if (_isEmpty != isEmpty) {
      setState(() {
        _isEmpty = isEmpty;
      });
    }
  }

  void _handleSend() {
    if (!_isEmpty) {
      HapticFeedback.lightImpact();
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyToMessage != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 16,
                    color: Colors.cyan.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to: ${widget.replyToMessage}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.cyan.shade300,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onCancelReply,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                  cursorColor: const Color(0xFF007AFF),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: const TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  scrollPhysics: const BouncingScrollPhysics(),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: _isEmpty
                    ? _CircleActionButton(
                        key: const ValueKey<String>('mic'),
                        icon: Icons.mic_rounded,
                        backgroundColor: const Color(0xFF007AFF),
                        iconColor: Colors.white,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showComingSoonMessage();
                        },
                      )
                    : _CircleActionButton(
                        key: const ValueKey<String>('send'),
                        icon: Icons.send_rounded,
                        backgroundColor: const Color(0xFF007AFF),
                        iconColor: Colors.white,
                        onTap: _handleSend,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.backgroundColor = const Color(0xFF1B2128),
    this.iconColor = Colors.white70,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: iconColor),
        ),
      ),
    );
  }
}
