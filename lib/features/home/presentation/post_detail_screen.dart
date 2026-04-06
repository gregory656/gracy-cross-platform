import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/utils/post_share_text.dart';
import '../providers/post_providers.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  Future<void> _reloadPost() async {
    ref.invalidate(postByIdProvider(widget.postId));
    await ref.read(postByIdProvider(widget.postId).future);
  }

  String _primaryRouteFor(AuthState authState) {
    if (authState.userId != null && !authState.isOnboardingComplete) {
      return AppRoutePaths.onboarding;
    }

    if (authState.isOnboardingComplete) {
      return AppRoutePaths.home;
    }

    return AppRoutePaths.welcome;
  }

  void _handlePostDeleted() {
    if (!mounted) {
      return;
    }

    final AuthState authState = ref.read(authNotifierProvider);
    context.go(_primaryRouteFor(authState));
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authNotifierProvider);
    final postAsync = ref.watch(postByIdProvider(widget.postId));

    return postAsync.when(
      loading: () => const _DeepLinkLoadingScreen(),
      error: (Object error, StackTrace stackTrace) {
        return _PostStatusScaffold(
          title: 'Post unavailable',
          description:
              'We could not open that shared post right now. Try again or jump back into Gracy.',
          primaryLabel: _primaryActionLabel(authState),
          onPrimaryPressed: () => context.go(_primaryRouteFor(authState)),
          secondaryLabel: 'Try again',
          onSecondaryPressed: _reloadPost,
        );
      },
      data: (post) {
        return Scaffold(
          backgroundColor: AppColors.onyx,
          appBar: AppBar(
            backgroundColor: AppColors.onyx,
            foregroundColor: AppColors.pureWhite,
            title: const Text('Shared Post'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Share',
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(text: buildPostShareText(post)),
                  );
                },
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: AppColors.electricBlue,
            backgroundColor: AppColors.onyx,
            onRefresh: _reloadPost,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: <Widget>[
                const _SharedPostHeader(),
                const SizedBox(height: 16),
                PostCard(
                  post: post,
                  onPostChanged: _reloadPost,
                  onPostDeleted: _handlePostDeleted,
                ),
                _JoinNetworkCard(
                  title: _networkCardTitle(authState),
                  description: _networkCardDescription(authState),
                  buttonLabel: _primaryActionLabel(authState),
                  onPressed: () => context.go(_primaryRouteFor(authState)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _primaryActionLabel(AuthState authState) {
    if (authState.userId != null && !authState.isOnboardingComplete) {
      return 'Finish onboarding';
    }

    if (authState.isOnboardingComplete) {
      return 'Open feed';
    }

    return 'Join the network';
  }

  String _networkCardTitle(AuthState authState) {
    if (authState.isOnboardingComplete) {
      return 'Keep exploring Gracy';
    }

    return 'Join the network';
  }

  String _networkCardDescription(AuthState authState) {
    if (authState.userId != null && !authState.isOnboardingComplete) {
      return 'Finish setting up your profile so shared posts open straight into your feed next time.';
    }

    if (authState.isOnboardingComplete) {
      return 'Jump back into the feed, keep sharing posts, and pull more people into the Gracy loop.';
    }

    return 'Set up Gracy on this device so shared posts, profiles, and chats open right where they should.';
  }
}

class _DeepLinkLoadingScreen extends StatelessWidget {
  const _DeepLinkLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.onyx,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _GracyWordmark(),
              SizedBox(height: 28),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.electricBlue,
                  ),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Loading shared post...',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostStatusScaffold extends StatelessWidget {
  const _PostStatusScaffold({
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.secondaryLabel,
    required this.onSecondaryPressed,
  });

  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final String secondaryLabel;
  final Future<void> Function() onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.onyx,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _GracyWordmark(),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        const Icon(
                          Icons.link_off_rounded,
                          color: AppColors.electricBlue,
                          size: 42,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge?.copyWith(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onPrimaryPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.electricBlue,
                              foregroundColor: AppColors.pureWhite,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(primaryLabel),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: onSecondaryPressed,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.pureWhite,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(secondaryLabel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedPostHeader extends StatelessWidget {
  const _SharedPostHeader();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.electricBlue.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Shared from Gracy',
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.electricBlue,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open the post, share it again, or pull people into the network from this exact moment.',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinNetworkCard extends StatelessWidget {
  const _JoinNetworkCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.pureWhite,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                foregroundColor: AppColors.pureWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _GracyWordmark extends StatelessWidget {
  const _GracyWordmark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.circle, color: AppColors.electricBlue, size: 14),
          SizedBox(width: 12),
          Text(
            'GRACY',
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 5,
            ),
          ),
        ],
      ),
    );
  }
}
