import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/disappearing_messages_service.dart';

class DisappearingMessagesDialog extends ConsumerWidget {
  const DisappearingMessagesDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DisappearingDuration currentDuration = ref.watch(disappearingMessagesProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Text('Disappearing Messages'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set a timer for messages to disappear after they\'ve been seen.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          ...DisappearingDuration.values.map((duration) {
            final isSelected = duration == currentDuration;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () {
                ref.read(disappearingMessagesProvider.notifier).setDuration(
                  duration,
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Disappearing messages set to ${duration.label}',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(duration.label),
              subtitle: duration == DisappearingDuration.off
                  ? const Text('Messages will not disappear')
                  : Text('Messages disappear after ${duration.label}'),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
