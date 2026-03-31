import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/mock_providers.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../widgets/profile_banner.dart';
import '../widgets/profile_quick_actions.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    this.userId,
  });

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<UserModel> users = ref.watch(mockUsersProvider);
    final UserModel user = userId == null
        ? users.first
        : ref.watch(userByIdProvider(userId!)) ?? users.first;

    void showQuickActions() {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return ProfileQuickActionsSheet(
            user: user,
            onChat: () {
              Navigator.of(sheetContext).pop();
              _openChat(context, ref, user);
            },
            onConnect: () {
              Navigator.of(sheetContext).pop();
              _showSnackBar(context, 'Connection request prepared for ${user.fullName}.');
            },
            onShare: () {
              Navigator.of(sheetContext).pop();
              _showSnackBar(context, 'Profile link copied for ${user.fullName}.');
            },
            onSave: () {
              Navigator.of(sheetContext).pop();
              _showSnackBar(context, '${user.fullName} saved to contacts.');
            },
            onReport: () {
              Navigator.of(sheetContext).pop();
              _showSnackBar(context, 'Report queued for review.');
            },
          );
        },
      );
    }

    void handleConnect() {
      _showSnackBar(context, 'Connection request prepared for ${user.fullName}.');
    }

    void handleShare() {
      _showSnackBar(context, 'Profile link copied for ${user.fullName}.');
    }

    void handleSave() {
      _showSnackBar(context, '${user.fullName} saved to contacts.');
    }

    void handleReport() {
      _showSnackBar(context, 'Report queued for review.');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutePaths.home);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.background,
              AppColors.backgroundAlt,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 920;

            final Widget primaryColumn = ListView(
              padding: AppConstants.screenPadding,
              children: <Widget>[
                ProfileBanner(user: user),
                const SizedBox(height: 18),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Bio',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user.bio,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Courses',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.courses
                            .map((String course) => _CourseChip(label: course))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: CustomButton(
                        label: 'Message',
                        icon: Icons.chat_rounded,
                        onPressed: () => _openChat(context, ref, user),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        label: 'Actions',
                        icon: Icons.menu_rounded,
                        filled: false,
                        onPressed: showQuickActions,
                      ),
                    ),
                  ],
                ),
                if (!isWide) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: CustomButton(
                          label: 'Connect',
                          icon: Icons.link_rounded,
                          filled: false,
                          onPressed: handleConnect,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );

            if (!isWide) {
              return primaryColumn;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: primaryColumn,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 360,
                  child: ListView(
                    padding: AppConstants.screenPadding,
                    children: <Widget>[
                      ProfileQuickActionsPanel(
                        user: user,
                        onChat: () => _openChat(context, ref, user),
                        onConnect: handleConnect,
                        onShare: handleShare,
                        onSave: handleSave,
                        onReport: handleReport,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _openChat(BuildContext context, WidgetRef ref, UserModel user) {
  final List<ChatModel> chats = ref.read(mockChatsProvider);
  final ChatModel? chat = chats.where((ChatModel entry) => entry.participantId == user.id).isNotEmpty
      ? chats.firstWhere((ChatModel entry) => entry.participantId == user.id)
      : null;
  if (chat != null) {
    context.go('${AppRoutePaths.chat}?chatId=${chat.id}');
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _CourseChip extends StatelessWidget {
  const _CourseChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
