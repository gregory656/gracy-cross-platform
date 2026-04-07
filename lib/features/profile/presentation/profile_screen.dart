import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/connection_model.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/mock_providers.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../../shared/providers/social_providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../home/providers/post_providers.dart';
import '../widgets/profile_banner.dart';
import '../widgets/profile_quick_actions.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<UserModel> users = ref.watch(mockUsersProvider);
    final UserModel? currentUser = ref.watch(currentUserProvider);
    final AsyncValue<UserModel?> profileAsync = userId == null
        ? const AsyncData<UserModel?>(null)
        : ref.watch(profileByIdProvider(userId!));

    final UserModel user = profileAsync.when(
      data: (UserModel? profile) {
        return userId == null
            ? currentUser ?? users.first
            : profile ??
                  (currentUser?.id == userId ? currentUser : null) ??
                  users.first;
      },
      loading: () => currentUser ?? users.first,
      error: (Object error, StackTrace stackTrace) =>
          currentUser ?? users.first,
    );

    final AsyncValue<List<PostModel>> postsAsync = ref.watch(postsProvider);
    final AsyncValue<List<ConnectionModel>> connectionsAsync =
        user.id == currentUser?.id
        ? ref.watch(connectionsStreamProvider)
        : const AsyncData<List<ConnectionModel>>(<ConnectionModel>[]);

    final List<_ProfileStatData> stats = <_ProfileStatData>[
      _ProfileStatData(
        value: _formatCompactCount(_resolvePostCount(postsAsync, user)),
        label: 'Posts',
      ),
      _ProfileStatData(
        value: _formatCompactCount(
          _resolveConnectionCount(connectionsAsync, user, users, currentUser),
        ),
        label: 'Connections',
      ),
      _ProfileStatData(
        value: _formatCompactCount(user.courses.length),
        label: 'Courses',
      ),
    ];

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
              _showSnackBar(
                context,
                'Connection request prepared for ${user.fullName}.',
              );
            },
            onShare: () {
              Navigator.of(sheetContext).pop();
              _showSnackBar(
                context,
                'Profile link copied for ${user.fullName}.',
              );
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
      _showSnackBar(
        context,
        'Connection request prepared for ${user.fullName}.',
      );
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
            colors: <Color>[AppColors.background, AppColors.backgroundAlt],
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ProfileStatsRow(stats: stats),
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
                      child: _ProfileActionButton(
                        label: 'Message',
                        icon: Icons.chat_rounded,
                        isPrimary: true,
                        onPressed: () => _openChat(context, ref, user),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileActionButton(
                        label: 'Actions',
                        icon: Icons.menu_rounded,
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
                        child: _ProfileActionButton(
                          label: 'Connect',
                          icon: Icons.link_rounded,
                          onPressed: handleConnect,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 120),
              ],
            );

            if (!isWide) {
              return primaryColumn;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 5, child: primaryColumn),
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
                      const SizedBox(height: 120),
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
  context.go('${AppRoutePaths.chat}?userId=${user.id}');
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.stats});

  final List<_ProfileStatData> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: List<Widget>.generate(stats.length * 2 - 1, (int index) {
          if (index.isOdd) {
            return Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.08),
            );
          }

          final _ProfileStatData stat = stats[index ~/ 2];
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  stat.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isPrimary
        ? AppColors.electricBlue
        : Colors.transparent;
    final Color borderColor = isPrimary ? AppColors.electricBlue : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: isPrimary
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.electricBlue.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStatData {
  const _ProfileStatData({required this.value, required this.label});

  final String value;
  final String label;
}

int _resolvePostCount(AsyncValue<List<PostModel>> postsAsync, UserModel user) {
  return postsAsync.maybeWhen(
    data: (List<PostModel> posts) {
      final int liveCount = posts
          .where((PostModel post) => post.authorId == user.id)
          .length;
      return liveCount > 0 ? liveCount : _estimatedPostCount(user);
    },
    orElse: () => _estimatedPostCount(user),
  );
}

int _resolveConnectionCount(
  AsyncValue<List<ConnectionModel>> connectionsAsync,
  UserModel user,
  List<UserModel> users,
  UserModel? currentUser,
) {
  final int estimatedCount = _estimatedConnectionCount(user, users);
  if (currentUser?.id != user.id) {
    return estimatedCount;
  }

  return connectionsAsync.maybeWhen(
    data: (List<ConnectionModel> connections) {
      final int liveCount = connections
          .where(
            (ConnectionModel connection) => connection.status == 'connected',
          )
          .length;
      return liveCount > 0 ? liveCount : estimatedCount;
    },
    orElse: () => estimatedCount,
  );
}

int _estimatedPostCount(UserModel user) {
  final int courseCount = user.courses.isEmpty ? 1 : user.courses.length;
  final int activityBoost = user.isOnline ? 8 : 5;
  final int roleBoost = user.role == UserRole.alumni ? 7 : 4;
  return courseCount * 5 + activityBoost + roleBoost;
}

int _estimatedConnectionCount(UserModel user, List<UserModel> users) {
  final int relatedProfiles = users.where((UserModel candidate) {
    if (candidate.id == user.id) {
      return false;
    }

    final bool sharesLocation = candidate.location == user.location;
    final bool sharesRole = candidate.role == user.role;
    final bool sharesCourse = candidate.courses.any(user.courses.contains);
    return sharesLocation || sharesRole || sharesCourse;
  }).length;

  final int baseCount = user.role == UserRole.alumni ? 96 : 64;
  return baseCount + (relatedProfiles * 18) + (user.isOnline ? 12 : 0);
}

String _formatCompactCount(int value) {
  if (value >= 1000) {
    final double compactValue = value / 1000;
    final String rounded = compactValue >= 10
        ? compactValue.toStringAsFixed(0)
        : compactValue.toStringAsFixed(1);
    return '${rounded}K';
  }

  return value.toString();
}
