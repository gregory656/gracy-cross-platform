import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/profile_card.dart';
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
        // Load initial posts
        ref.read(postsProvider.notifier).refresh();
      }
    });

    _scrollController.addListener(_onScroll);
  }

  Future<void> _triggerContactSync() async {
    try {
      // TODO: Re-enable when contact service is fixed
      // final contactService = ref.read(contactServiceProvider);
      // await contactService.showContactSyncDialog(context);
    } catch (e) {
      // Silently fail for contact sync
      // print('Contact sync failed: $e');
    }
  }

  @override
  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<UserModel>> profilesAsync = ref.watch(
      profilesDirectoryProvider,
    );
    final List<UserModel> fallbackUsers = mockUsers;
    final UserModel headerUser =
        ref.watch(currentUserProvider) ?? fallbackUsers.first;
    final String query = _query.toLowerCase().trim();
    final postsAsync = ref.watch(postsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: _showPosts ? const CreatePostButton() : null,
      body: SafeArea(
        child: _showPosts
            ? _buildPostsView(postsAsync, headerUser)
            : profilesAsync.when(
                loading: () => _buildDirectory(context, fallbackUsers, headerUser, query),
                error: (Object error, StackTrace stackTrace) =>
                    _buildDirectory(context, fallbackUsers, headerUser, query),
                data: (List<UserModel> users) =>
                    _buildDirectory(context, users, headerUser, query),
              ),
      ),
    );
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
                  context.go('${AppRoutePaths.profile}?userId=${user.id}');
                },
                onPrimaryAction: () {
                  context.go('${AppRoutePaths.chat}?userId=${user.id}');
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPostsView(AsyncValue<List<PostModel>> postsAsync, UserModel headerUser) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(postsProvider.notifier).refresh();
      },
      color: const Color(0xFF00D4FF),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: AppConstants.screenPadding,
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  HomeHeader(user: headerUser),
                  const SizedBox(height: 18),
                  _ViewToggle(
                    showPosts: _showPosts,
                    onToggle: () {
                      setState(() {
                        _showPosts = !_showPosts;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          postsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                  ),
                ),
              ),
            ),
            error: (error, stackTrace) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load posts',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[400],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(postsProvider.notifier).refresh();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          foregroundColor: Colors.black,
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
                            color: Colors.grey[400],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No posts yet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to create a post!',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[400],
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
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                          ),
                        ),
                      );
                    }
                    return PostCard(post: posts[index]);
                  },
                  childCount: posts.length + 1,
                ),
              );
            },
          ),
        ],
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
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: showPosts ? null : onToggle,
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: showPosts ? const Color(0xFF00D4FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Center(
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      color: showPosts ? Colors.black : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: !showPosts ? null : onToggle,
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: !showPosts ? const Color(0xFF00D4FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Center(
                  child: Text(
                    'Profiles',
                    style: TextStyle(
                      color: !showPosts ? Colors.black : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
