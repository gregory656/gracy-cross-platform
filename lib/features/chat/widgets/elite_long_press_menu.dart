import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import '../../../shared/models/message_model.dart';
import '../../../core/theme/app_colors.dart';

enum EliteMenuAction { reply, forward, copy, delete }

class EliteLongPressMenu extends StatelessWidget {
  const EliteLongPressMenu({
    super.key,
    required this.message,
    required this.onActionSelected,
  });

  final MessageModel message;
  final Function(EliteMenuAction) onActionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.onyx,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.borderGray,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pureWhite.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.industrialGray,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.borderGray,
                  width: 1,
                ),
              ),
            ),
            child: Text(
              'Message Options',
              style: const TextStyle(
                color: AppColors.pureWhite,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          
          // Message preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.borderGray,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: const TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.text,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Action buttons
          ..._buildActionButtons(context),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    final actions = [
      _MenuAction(
        icon: Icons.reply,
        label: 'Reply',
        action: EliteMenuAction.reply,
      ),
      _MenuAction(
        icon: Icons.forward,
        label: 'Forward',
        action: EliteMenuAction.forward,
      ),
      _MenuAction(
        icon: Icons.copy,
        label: 'Copy',
        action: EliteMenuAction.copy,
      ),
      if (message.isMe)
        _MenuAction(
          icon: Icons.delete,
          label: 'Delete',
          action: EliteMenuAction.delete,
          isDestructive: true,
        ),
    ];

    return actions.map((action) {
      return _buildActionButton(
        context: context,
        icon: action.icon,
        label: action.label,
        action: action.action,
        isDestructive: action.isDestructive,
      );
    }).toList();
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required EliteMenuAction action,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        onActionSelected(action);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? AppColors.error : AppColors.electricBlue,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? AppColors.error : AppColors.pureWhite,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuAction {
  final IconData icon;
  final String label;
  final EliteMenuAction action;
  final bool isDestructive;

  _MenuAction({
    required this.icon,
    required this.label,
    required this.action,
    this.isDestructive = false,
  });
}

// Utility functions for menu actions
class EliteMenuActions {
  static void handleReply(BuildContext context, MessageModel message) {
    // This will be handled by the parent chat screen
    Navigator.of(context).pop(message);
  }

  static void handleCopy(MessageModel message) {
    Clipboard.setData(ClipboardData(text: message.text));
    HapticFeedback.selectionClick();
  }

  static void handleShare(MessageModel message) {
    // Simple share implementation
    Clipboard.setData(ClipboardData(text: message.text));
  }

  static void handleDelete(BuildContext context, MessageModel message) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.onyx,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.borderGray),
        ),
        title: const Text(
          'Delete Message',
          style: TextStyle(color: AppColors.pureWhite),
        ),
        content: const Text(
          'This message will be deleted permanently. This action cannot be undone.',
          style: TextStyle(color: AppColors.lightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.electricBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Handle actual deletion
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.pureWhite,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
