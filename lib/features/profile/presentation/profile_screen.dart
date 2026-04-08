import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/mock_providers.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../home/providers/post_providers.dart';
import '../../home/widgets/post_card.dart';
import '../../settings/presentation/edit_profile_screen.dart';

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
      error: (_, _) => currentUser ?? users.first,
    );

    final bool isOwner = currentUser?.id == user.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.onyx,
        appBar: AppBar(
          backgroundColor: AppColors.onyx,
          title: Text(user.username),
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
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppConstants.screenPadding,
                  child: _ProfileHeader(
                    user: user,
                    isOwner: isOwner,
                    onPrimaryAction: () {
                      if (isOwner) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                EditProfileScreen(user: user),
                          ),
                        );
                        return;
                      }
                      context.go('${AppRoutePaths.chat}?userId=${user.id}');
                    },
                    onSecondaryAction: () {
                      final String message = isOwner
                          ? 'Profile link copied for ${user.fullName}.'
                          : 'Connection request prepared for ${user.fullName}.';
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(message),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    },
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabHeaderDelegate(
                  child: Container(
                    color: AppColors.onyx,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const TabBar(
                        indicatorColor: AppColors.electricBlue,
                        labelColor: AppColors.pureWhite,
                        unselectedLabelColor: AppColors.lightGray,
                        dividerColor: Colors.transparent,
                        tabs: <Widget>[
                          Tab(icon: Icon(Icons.grid_on_rounded), text: 'Grid'),
                          Tab(
                            icon: Icon(Icons.view_agenda_rounded),
                            text: 'List',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: <Widget>[
              _ProfileGridTab(user: user, isOwner: isOwner),
              _ProfileListTab(user: user),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.user,
    required this.isOwner,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  final UserModel user;
  final bool isOwner;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PostModel>> userPostsAsync = ref.watch(
      userPostsProvider(user.id),
    );
    final AsyncValue<int> totalReachAsync = ref.watch(totalReachProvider(user.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: AppColors.onyx,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _CircularProfileImage(user: user, size: 92),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.pureWhite,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.username}  •  ${user.role.label}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.lightGray,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (user.gracyId != null)
                                _MetricChip(
                                  icon: Icons.badge_outlined,
                                  label: user.gracyId!,
                                ),
                              _MetricChip(
                                icon: Icons.location_on_outlined,
                                label: user.location,
                              ),
                              _MetricChip(
                                icon: Icons.circle,
                                label: user.isOnline ? 'Online' : 'Offline',
                                iconSize: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  user.bio,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.pureWhite,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricPanel(
                        label: 'Reach',
                        icon: Icons.analytics_outlined,
                        value: totalReachAsync.when(
                          data: _formatCompactCount,
                          loading: () => '...',
                          error: (_, _) => '0',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricPanel(
                        label: 'Posts',
                        icon: Icons.photo_library_outlined,
                        value: userPostsAsync.when(
                          data: (List<PostModel> posts) =>
                              _formatCompactCount(posts.length),
                          loading: () => '...',
                          error: (_, _) => '0',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _HeaderButton(
                        label: isOwner ? 'Edit Profile' : 'Connect',
                        icon: isOwner
                            ? Icons.edit_outlined
                            : Icons.person_add_alt_1_rounded,
                        isPrimary: true,
                        onPressed: onPrimaryAction,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HeaderButton(
                        label: isOwner ? 'Share Profile' : 'Message',
                        icon: isOwner
                            ? Icons.ios_share_outlined
                            : Icons.chat_bubble_outline_rounded,
                        isPrimary: false,
                        onPressed: onSecondaryAction,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileGridTab extends ConsumerWidget {
  const _ProfileGridTab({required this.user, required this.isOwner});

  final UserModel user;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PostModel>> userPostsAsync = ref.watch(
      userPostsProvider(user.id),
    );

    return userPostsAsync.when(
      data: (List<PostModel> posts) {
        final List<PostModel> imagePosts = posts
            .where((PostModel post) => post.imageUrl?.isNotEmpty == true)
            .toList(growable: false);

        if (imagePosts.isEmpty) {
          return const _EmptyFeedState(
            title: 'No visual posts yet',
            subtitle: 'Photo posts will appear here in a 3-column grid.',
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refreshProfileFeed(ref, user.id),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
              childAspectRatio: 1,
            ),
            itemCount: imagePosts.length,
            itemBuilder: (BuildContext context, int index) {
              final PostModel post = imagePosts[index];
              return _GridPostTile(
                post: post,
                isOwner: isOwner,
                onManage: () => _showGridManageSheet(
                  context: context,
                  ref: ref,
                  userId: user.id,
                  post: post,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => _EmptyFeedState(
        title: 'Profile feed unavailable',
        subtitle: error.toString(),
      ),
    );
  }
}

class _ProfileListTab extends ConsumerWidget {
  const _ProfileListTab({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PostModel>> userPostsAsync = ref.watch(
      userPostsProvider(user.id),
    );

    return userPostsAsync.when(
      data: (List<PostModel> posts) {
        if (posts.isEmpty) {
          return const _EmptyFeedState(
            title: 'No posts yet',
            subtitle: 'Full post cards will show up here as soon as content lands.',
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refreshProfileFeed(ref, user.id),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            itemCount: posts.length,
            itemBuilder: (BuildContext context, int index) {
              final PostModel post = posts[index];
              return PostCard(
                post: post,
                onPostChanged: () => _refreshProfileFeed(ref, user.id),
                onPostDeleted: () => _refreshProfileFeed(ref, user.id),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => _EmptyFeedState(
        title: 'Could not load posts',
        subtitle: error.toString(),
      ),
    );
  }
}

class _GridPostTile extends StatelessWidget {
  const _GridPostTile({
    required this.post,
    required this.isOwner,
    required this.onManage,
  });

  final PostModel post;
  final bool isOwner;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(
          color: Colors.white.withValues(alpha: 0.03),
          child: CachedNetworkImage(
            imageUrl: post.optimizedImageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              color: Colors.white.withValues(alpha: 0.06),
            ),
            errorWidget: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white54),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _GridStat(
                        icon: Icons.favorite_border,
                        label: post.likesVisible
                            ? _formatCompactCount(post.likesCount)
                            : 'Hidden',
                      ),
                      _GridStat(
                        icon: Icons.analytics_outlined,
                        label: _formatCompactCount(post.viewCount),
                      ),
                    ],
                  ),
                ),
              ),
              if (isOwner) ...<Widget>[
                const SizedBox(width: 6),
                Material(
                  color: AppColors.electricBlue,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onManage,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        'Manage',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CircularProfileImage extends StatelessWidget {
  const _CircularProfileImage({required this.user, required this.size});

  final UserModel user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: user.avatarUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => _AvatarFallback(initials: user.initials),
              errorWidget: (_, _, _) => _AvatarFallback(initials: user.initials),
            )
          : _AvatarFallback(initials: user.initials),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.electricBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.pureWhite,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.lightGray,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    this.iconSize = 16,
  });

  final IconData icon;
  final String label;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.electricBlue, size: iconSize),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.pureWhite,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.electricBlue : Colors.white,
          foregroundColor: isPrimary ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isPrimary ? AppColors.electricBlue : Colors.white,
            ),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _GridStat extends StatelessWidget {
  const _GridStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.photo_filter_outlined, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabHeaderDelegate({required this.child});

  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

Future<void> _refreshProfileFeed(WidgetRef ref, String userId) async {
  ref.invalidate(userPostsProvider(userId));
  ref.invalidate(totalReachProvider(userId));
  await ref.read(postsProvider.notifier).refresh();
}

Future<void> _showGridManageSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required PostModel post,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(
                    post.likesVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white,
                  ),
                  title: Text(
                    post.likesVisible ? 'Hide Like Count' : 'Show Like Count',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref.read(postsProvider.notifier).setLikesVisibility(
                          postId: post.id,
                          isVisible: !post.likesVisible,
                        );
                    await _refreshProfileFeed(ref, userId);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref.read(postsProvider.notifier).deletePost(post.id);
                    await _refreshProfileFeed(ref, userId);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _formatCompactCount(int value) {
  if (value >= 1000000) {
    final double compactValue = value / 1000000;
    return compactValue >= 10
        ? '${compactValue.toStringAsFixed(0)}M'
        : '${compactValue.toStringAsFixed(1)}M';
  }

  if (value >= 1000) {
    final double compactValue = value / 1000;
    return compactValue >= 10
        ? '${compactValue.toStringAsFixed(0)}K'
        : '${compactValue.toStringAsFixed(1)}K';
  }

  return value.toString();
}
