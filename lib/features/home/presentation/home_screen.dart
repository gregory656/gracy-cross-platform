import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../../shared/services/presence_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/mock_data/mock_users.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/profile_card.dart';
import '../../../shared/models/feed_category.dart';
import '../widgets/home_header.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_button.dart';
import '../providers/post_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _showPosts = true;
  String? _selectedCategory; // null means "All"
  Timer? _feedChromeTimer;
  bool _isFeedChromeVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AuthState authState = ref.read(authNotifierProvider);
      final String? userId = authState.userId;
      if (userId != null) {
        PresenceService.instance.markOnline(userId);
        // Trigger contact sync
        _triggerContactSync();
        _primeHomeData();
      }
    });

    _scrollController.addListener(_onScroll);
    _scheduleFeedChromeHide();
  }

  Future<void> _primeHomeData() async {
    try {
      await Future.wait<Object?>(<Future<Object?>>[
        ref.read(profilesDirectoryProvider.future),
        ref.read(postsProvider.future),
      ]);
    } catch (_) {
      // Let the individual providers surface cached data or their own errors.
    }
  }

  Future<void> _triggerContactSync() async {
    try {
      // Contact sync stays disabled until the Flutter contacts integration is restored.
      // final contactService = ref.read(contactServiceProvider);
      // await contactService.showContactSyncDialog(context);
    } catch (_) {
      // Silently fail for contact sync
    }
  }

  @override
  void dispose() {
    _feedChromeTimer?.cancel();
    PresenceService.instance.markOffline();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(postsProvider.notifier).loadMore();
    }

    if (!_scrollController.hasClients) {
      return;
    }

    final ScrollDirection direction =
        _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.forward) {
      _showFeedChrome();
    } else if (direction == ScrollDirection.reverse &&
        _scrollController.position.pixels > 40) {
      _hideFeedChrome();
    }
  }

  void _scheduleFeedChromeHide() {
    _feedChromeTimer?.cancel();
    _feedChromeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_showPosts) {
        return;
      }
      setState(() {
        _isFeedChromeVisible = false;
      });
    });
  }

  void _showFeedChrome() {
    if (!_showPosts) {
      return;
    }
    if (!_isFeedChromeVisible) {
      setState(() {
        _isFeedChromeVisible = true;
      });
    }
    _scheduleFeedChromeHide();
  }

  void _hideFeedChrome() {
    _feedChromeTimer?.cancel();
    if (_isFeedChromeVisible) {
      setState(() {
        _isFeedChromeVisible = false;
      });
    }
  }

  Future<void> _onCategorySelected(String? category) async {
    if (_selectedCategory == category) return;
    
    setState(() {
      _selectedCategory = category;
    });
    
    await ref.read(postsProvider.notifier).setFeedCategory(category);
  }

  Future<void> _handleBackNavigation() async {
    if (!_showPosts) {
      setState(() {
        _showPosts = true;
      });
      return;
    }

    final bool shouldExit = await _showExitDialog() ?? false;
    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B0D10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          title: const Text(
            'Leaving Gracy?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Are you sure?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'No',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authNotifierProvider);
    final AsyncValue<List<UserModel>> profilesAsync = ref.watch(
      profilesDirectoryProvider,
    );
    final List<UserModel> fallbackUsers = mockUsers;
    final UserModel? currentUser = ref.watch(resolvedCurrentUserProvider);
    final List<UserModel> availableProfiles =
        profilesAsync.asData?.value ?? fallbackUsers;
    final UserModel headerUser = _resolveHeaderUser(
      authState: authState,
      currentUser: currentUser,
      profiles: availableProfiles,
      fallbackUsers: fallbackUsers,
    );
    final String query = _query.toLowerCase().trim();
    final postsAsync = ref.watch(postsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        bool didPop,
        Object? result,
      ) async {
        if (didPop) {
          return;
        }
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: _showPosts
              ? _buildPostsView(
                  postsAsync,
                  headerUser,
                  profilesAsync.asData?.value ?? fallbackUsers,
                )
              : profilesAsync.when(
                  loading: () => _buildDirectory(context, fallbackUsers, headerUser, query),
                  error: (Object error, StackTrace stackTrace) =>
                      _buildDirectory(context, fallbackUsers, headerUser, query),
                  data: (List<UserModel> users) =>
                      _buildDirectory(context, users, headerUser, query),
                ),
        ),
      ),
    );
  }

  UserModel _resolveHeaderUser({
    required AuthState authState,
    required UserModel? currentUser,
    required List<UserModel> profiles,
    required List<UserModel> fallbackUsers,
  }) {
    final String? userId = authState.userId;
    if (userId != null) {
      for (final UserModel profile in profiles) {
        if (profile.id == userId) {
          if (currentUser == null) {
            return profile;
          }

          return currentUser.copyWith(
            fullName: profile.fullName,
            username: profile.username,
            bio: profile.bio,
            year: profile.year,
            avatarSeed: profile.avatarSeed,
            avatarUrl: profile.avatarUrl ?? currentUser.avatarUrl,
            gracyId: profile.gracyId ?? currentUser.gracyId,
          );
        }
      }
    }

    return currentUser ?? fallbackUsers.first;
  }

  Widget _buildDirectory(
    BuildContext context,
    List<UserModel> users,
    UserModel headerUser,
    String query,
  ) {
    final List<UserModel> filteredUsers = users.where((UserModel user) {
      if (query.isEmpty) {
        return true;
      }
      return user.fullName.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          user.bio.toLowerCase().contains(query) ||
          user.year.toLowerCase().contains(query) ||
          (user.gracyId?.toLowerCase().contains(query) ?? false) ||
          user.courses.any(
            (String course) => course.toLowerCase().contains(query),
          );
    }).toList();

    return ListView(
      padding: AppConstants.screenPadding,
      children: <Widget>[
        HomeHeader(user: headerUser),
        const SizedBox(height: 18),
        CustomTextField(
          controller: _searchController,
          hintText: 'Search by name or Gracy code',
          prefixIcon: Icons.search_rounded,
          height: 48,
          onChanged: (String value) {
            setState(() {
              _query = value;
            });
          },
        ),
        const SizedBox(height: 16),
        _QuickStats(users.length),
        const SizedBox(height: 16),
        _ViewToggle(
          showPosts: _showPosts,
          onToggle: () {
            setState(() {
              _showPosts = !_showPosts;
            });
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'All Profiles',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              '${filteredUsers.length} matches',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (filteredUsers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No profiles found yet.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          ...filteredUsers.map((UserModel user) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
                child: ProfileCard(
                user: user,
                onTap: () {
                  context.push('${AppRoutePaths.profile}?userId=${user.id}');
                },
                onPrimaryAction: () {
                  context.push(
                    AppRoutePaths.chatByUser(
                      userId: user.id,
                      receiverName: user.fullName,
                      receiverAvatar: user.avatarUrl,
                    ),
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPostsView(
    AsyncValue<List<PostModel>> postsAsync,
    UserModel headerUser,
    List<UserModel> users,
  ) {
    final postsNotifier = ref.read(postsProvider.notifier);
    final uploadProgress = postsNotifier.progress;
    final uploadStatus = postsNotifier.status;
    final isUploading = uploadProgress > 0 && uploadProgress < 1;
    final List<UserModel> activeUsers = users
        .where((UserModel user) => user.id != headerUser.id && user.isOnline)
        .toList(growable: false);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _showFeedChrome(),
      child: RefreshIndicator(
        onRefresh: () async {
          _showFeedChrome();
          await ref.read(postsProvider.notifier).refresh();
        },
        color: const Color(0xFF00D4FF),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHomeHeaderDelegate(
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                alignment: Alignment.bottomCenter,
                child: HomeHeader(user: headerUser),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: <Widget>[
                  _StoriesRow(currentUser: headerUser, activeUsers: activeUsers),
                  const SizedBox(height: 14),
                  _CategoryChips(
                    selectedCategory: _selectedCategory,
                    onCategorySelected: _onCategorySelected,
                  ),
                  const SizedBox(height: 16),
                  CreatePostButton(
                    expanded: true,
                    promptText:
                        "What's on your mind, ${_firstName(headerUser.fullName)}?",
                  ),
                  const SizedBox(height: 16),
                  if (isUploading) ...<Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: uploadProgress <= 0 ? null : uploadProgress,
                        minHeight: 6,
                        backgroundColor: AppColors.textSecondary.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        uploadStatus.isEmpty ? 'Posting...' : uploadStatus,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          postsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (error, stackTrace) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load posts',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(postsProvider.notifier).refresh();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.feed_outlined,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No posts yet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to create a post!',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return PostCard(post: posts[index]);
                  },
                  childCount: posts.length + 1,
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool showPosts;
  final VoidCallback onToggle;

  const _ViewToggle({
    required this.showPosts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final Map<bool, Widget> segments = <bool, Widget>{
      true: const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'All Posts',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      false: const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'Profiles',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22007AFF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CupertinoSlidingSegmentedControl<bool>(
          groupValue: showPosts,
          backgroundColor: Colors.transparent,
          thumbColor: AppColors.electricBlue,
          children: segments,
          onValueChanged: (bool? value) {
            if (value != null && value != showPosts) {
              onToggle();
            }
          },
        ),
      ),
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({
    required this.currentUser,
    required this.activeUsers,
  });

  final UserModel currentUser;
  final List<UserModel> activeUsers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: activeUsers.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return _StoryAvatar(
              user: currentUser,
              label: 'Create',
              isCreateStory: true,
            );
          }

          final UserModel user = activeUsers[index - 1];
          return _StoryAvatar(user: user, label: _firstName(user.fullName));
        },
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.user,
    required this.label,
    this.isCreateStory = false,
  });

  final UserModel user;
  final String label;
  final bool isCreateStory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isCreateStory) {
          context.push('${AppRoutePaths.profile}?userId=${user.id}');
        }
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCreateStory
                          ? AppColors.electricBlue.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  child: UserAvatar(
                    user: user,
                    size: 58,
                    fontSize: 16,
                    showRing: false,
                    showOnlineIndicator: !isCreateStory,
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isCreateStory
                            ? AppColors.electricBlue
                            : const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    child: isCreateStory
                        ? const Icon(
                            Icons.add,
                            size: 10,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _firstName(String fullName) {
  final List<String> parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.isEmpty || parts.first.isEmpty ? 'you' : parts.first;
}

class _PinnedHomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHomeHeaderDelegate({required this.child});

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
  double get maxExtent => 92;

  @override
  double get minExtent => 92;

  @override
  bool shouldRebuild(covariant _PinnedHomeHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            label: 'Profiles',
            value: '$count',
            accent: AppColors.accentCyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Online',
            value: '4',
            accent: AppColors.accentBlue,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final String? selectedCategory;
  final Function(String?) onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kFeedCategoryChips.length + 1, // +1 for "All"
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // "All" chip
          if (index == 0) {
            final isSelected = selectedCategory == null;
            return CategoryChip(
              label: 'All',
              icon: Icons.apps,
              isSelected: isSelected,
              onTap: () => onCategorySelected(null),
            );
          }

          final category = kFeedCategoryChips[index - 1];
          final isSelected = selectedCategory == category.slug;
          
          return CategoryChip(
            label: category.label,
            icon: category.icon,
            isSelected: isSelected,
            onTap: () => onCategorySelected(category.slug),
          );
        },
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.electricBlue : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? AppColors.electricBlue 
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
