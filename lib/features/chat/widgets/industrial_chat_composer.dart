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
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyToMessage != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1,
                  ),
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
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                _CircleActionButton(
                  icon: Icons.attach_file_rounded,
                  onTap: _showComingSoonMessage,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 45),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            scrollPhysics: const BouncingScrollPhysics(),
                          ),
                        ),
                        _CircleActionButton(
                          icon: Icons.camera_alt_rounded,
                          backgroundColor: Colors.transparent,
                          iconColor: Colors.white60,
                          onTap: _showComingSoonMessage,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _isEmpty
                      ? _CircleActionButton(
                          key: const ValueKey<String>('mic'),
                          icon: Icons.mic_rounded,
                          backgroundColor: const Color(0xFF111922),
                          iconColor: Colors.white60,
                          onTap: () {
                            HapticFeedback.selectionClick();
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
