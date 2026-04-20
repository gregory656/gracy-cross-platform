import 'package:flutter/material.dart';

import '../models/user_model.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.fontSize,
    this.showRing = false,
    this.showOnlineIndicator = false,
  });

  final UserModel user;
  final double size;
  final double? fontSize;
  final bool showRing;
  final bool showOnlineIndicator;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
      child: user.avatarUrl == null
          ? Text(
              user.username[0].toUpperCase(),
              style: TextStyle(fontSize: fontSize ?? size * 0.4),
            )
          : null,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          padding: showRing ? const EdgeInsets.all(2) : EdgeInsets.zero,
          decoration: showRing
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                )
              : null,
          child: avatar,
        ),
        if (showOnlineIndicator)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: user.isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
