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
            return RadioListTile<DisappearingDuration>(
              title: Text(duration.label),
              subtitle: duration == DisappearingDuration.off 
                  ? const Text('Messages will not disappear')
                  : Text('Messages disappear after ${duration.label}'),
              value: duration,
              groupValue: currentDuration,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (DisappearingDuration? value) {
                if (value != null) {
                  ref.read(disappearingMessagesProvider.notifier).setDuration(value);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Disappearing messages set to ${value.label}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
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
