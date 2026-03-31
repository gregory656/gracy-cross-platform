import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accentCyan.withValues(alpha: 0.18)
              : AppColors.surfaceElevated.withValues(alpha: 0.82),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppConstants.cardRadius),
            topRight: const Radius.circular(AppConstants.cardRadius),
            bottomLeft: Radius.circular(isMe ? AppConstants.cardRadius : 8),
            bottomRight: Radius.circular(isMe ? 8 : AppConstants.cardRadius),
          ),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormatters.chatPreviewTime.format(message.sentAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

