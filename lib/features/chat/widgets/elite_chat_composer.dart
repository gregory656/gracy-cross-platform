import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/elite_animations.dart';

class EliteChatComposer extends StatefulWidget {
  const EliteChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Message',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;

  @override
  State<EliteChatComposer> createState() => _EliteChatComposerState();
}

class _EliteChatComposerState extends State<EliteChatComposer> {
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _isEmpty = widget.controller.text.trim().isEmpty;
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
      widget.onSend();
    }
  }

  void _showComingSoon() {
    EliteHaptics.lightImpact();
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
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Solid Black background as requested
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), // 8px padding around the entire bar
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.pureWhite, // Pure White pill-shaped container
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                        onPressed: _showComingSoon,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ),
                          isDense: true,
                        ),
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.attach_file_rounded, color: Colors.grey),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(12),
                            onPressed: _showComingSoon,
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt_rounded, color: Colors.grey),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(left: 4, right: 12, top: 12, bottom: 12),
                            onPressed: _showComingSoon,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
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
                  ? _buildActionButton(
                      key: const ValueKey('mic'),
                      icon: Icons.mic_rounded,
                      onTap: () {
                        EliteHaptics.lightImpact();
                        _showComingSoon();
                      },
                    )
                  : _buildActionButton(
                      key: const ValueKey('send'),
                      icon: Icons.send_rounded,
                      onTap: _handleSend,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return EliteAnimatedButton(
      key: key,
      onPressed: onTap,
      hapticType: HapticType.medium,
      child: Container(
        height: 48,
        width: 48,
        decoration: const BoxDecoration(
          color: AppColors.electricBlue,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.pureWhite,
          size: 24,
        ),
      ),
    );
  }
}
