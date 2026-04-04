import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_model.dart';
import '../../../shared/services/nairobi_timezone_service.dart';
import '../../../core/theme/app_colors.dart';

class EliteMessageBubble extends ConsumerStatefulWidget {
  const EliteMessageBubble({
    super.key,
    required this.message,
    required this.onLongPress,
  });

  final MessageModel message;
  final VoidCallback onLongPress;

  @override
  ConsumerState<EliteMessageBubble> createState() => _EliteMessageBubbleState();
}

class _EliteMessageBubbleState extends ConsumerState<EliteMessageBubble>
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleLongPress() {
    HapticFeedback.heavyImpact();
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    widget.onLongPress();
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isMe;
    final timezoneService = NairobiTimezoneService.instance;
    
    return GestureDetector(
      onLongPress: _handleLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: isMe 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  // Message bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe 
                          ? AppColors.electricBlue 
                          : AppColors.industrialGray,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isMe 
                            ? AppColors.electricBlue 
                            : AppColors.borderGray,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply preview (if exists)
                        if (widget.message.replyToId != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.onyx.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: AppColors.borderGray.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 14,
                                  color: AppColors.lightGray,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Replied message',
                                    style: const TextStyle(
                                      color: AppColors.lightGray,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Message text
                        Text(
                          widget.message.text,
                          style: TextStyle(
                            color: isMe 
                                ? AppColors.pureWhite 
                                : AppColors.pureWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Status row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Time
                            Text(
                              timezoneService.formatTime(widget.message.sentAt),
                              style: TextStyle(
                                color: isMe 
                                    ? AppColors.pureWhite.withValues(alpha: 0.7)
                                    : AppColors.lightGray,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              
                              // Status ticks
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: widget.message.statusTicks.map((icon) {
                                  return Icon(
                                    icon,
                                    size: 14,
                                    color: _getStatusColor(widget.message.status),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Sender name (for non-me messages in group chats)
                  if (!isMe) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        children: [
                          Text(
                            widget.message.senderName,
                            style: const TextStyle(
                              color: AppColors.lightGray,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.message.isOfficial) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 12,
                              color: AppColors.electricBlue,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return AppColors.sentGray;
      case MessageStatus.delivered:
        return AppColors.deliveredGray;
      case MessageStatus.read:
        return AppColors.readCyan;
    }
  }
}
