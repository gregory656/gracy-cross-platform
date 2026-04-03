import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
  });

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final bool isMe = message.isMe;
    final BorderRadius radius = BorderRadius.only(
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
      bottomLeft: Radius.circular(isMe ? 24 : 10),
      bottomRight: Radius.circular(isMe ? 10 : 24),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.accentBlue.withValues(alpha: 0.95),
                    AppColors.accentCyan.withValues(alpha: 0.92),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFF14243B).withValues(alpha: 0.96),
                    const Color(0xFF101C31).withValues(alpha: 0.96),
                  ],
                ),
          borderRadius: radius,
          border: Border.all(
            color: isMe
                ? Colors.white.withValues(alpha: 0.10)
                : AppColors.outline.withValues(alpha: 0.8),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isMe ? 0.18 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isMe) ...<Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        message.senderName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                    if (message.isOfficial) ...<Widget>[
                      const SizedBox(width: 8),
                      const _OfficialBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isMe ? AppColors.background : AppColors.textPrimary,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                DateFormatters.chatPreviewTime.format(message.sentAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isMe
                          ? AppColors.background.withValues(alpha: 0.72)
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentAmber.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        'Official',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accentAmber,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
