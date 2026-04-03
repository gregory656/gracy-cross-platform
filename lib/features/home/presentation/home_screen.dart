import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/mock_providers.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../../shared/services/presence_service.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/profile_card.dart';
import '../widgets/home_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AuthState authState = ref.read(authNotifierProvider);
      final String? userId = authState.userId;
      if (userId != null) {
        unawaited(PresenceService.instance.markOnline(userId));
      }
    });
  }

  @override
  void dispose() {
    unawaited(PresenceService.instance.markOffline());
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<UserModel>> profilesAsync = ref.watch(
      profilesDirectoryProvider,
    );
    final List<UserModel> fallbackUsers = ref.watch(mockUsersProvider);
    final UserModel headerUser =
        ref.watch(currentUserProvider) ?? fallbackUsers.first;
    final String query = _query.toLowerCase().trim();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.background,
              AppColors.backgroundAlt,
              Color(0xFF091725),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -60,
              right: -30,
              child: _GlowBlob(
                color: AppColors.accentBlue.withValues(alpha: 0.20),
              ),
            ),
            Positioned(
              top: 90,
              left: -20,
              child: _GlowBlob(
                color: AppColors.accentCyan.withValues(alpha: 0.16),
                size: 150,
              ),
            ),
            SafeArea(
              child: profilesAsync.when(
                loading: () => ListView(
                  padding: AppConstants.screenPadding,
                  children: <Widget>[
                    HomeHeader(user: headerUser),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _searchController,
                      hintText: 'Scan QR or enter join code',
                      prefixIcon: Icons.qr_code_scanner_rounded,
                      height: 48,
                      onChanged: (String value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _QuickStats(fallbackUsers.length),
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (Object error, StackTrace stackTrace) =>
                    _buildDirectory(context, fallbackUsers, headerUser, query),
                data: (List<UserModel> users) =>
                    _buildDirectory(context, users, headerUser, query),
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface.withValues(alpha: 0.88),
        border: Border.all(color: AppColors.outline),
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
              color: accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, this.size = 180});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color, blurRadius: 36, spreadRadius: 6),
        ],
      ),
    );
  }
}
