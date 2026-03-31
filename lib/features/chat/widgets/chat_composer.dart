import 'package:flutter/material.dart';

import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: CustomTextField(
            controller: controller,
            hintText: 'Type a message...',
            prefixIcon: Icons.chat_bubble_outline_rounded,
          ),
        ),
        const SizedBox(width: 12),
        CustomButton(
          label: 'Send',
          icon: Icons.send_rounded,
          onPressed: onSend,
        ),
      ],
    );
  }
}

