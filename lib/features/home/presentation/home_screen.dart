import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/mock_providers.dart';
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<UserModel> users = ref.watch(mockUsersProvider);
    final List<UserModel> filteredUsers = users.where((UserModel user) {
      final String query = _query.toLowerCase().trim();
      if (query.isEmpty) {
        return true;
      }
      return user.fullName.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          user.courses.any((String course) => course.toLowerCase().contains(query));
    }).toList();

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
              child: _GlowBlob(color: AppColors.accentBlue.withValues(alpha: 0.20)),
            ),
            Positioned(
              top: 90,
              left: -20,
              child: _GlowBlob(color: AppColors.accentCyan.withValues(alpha: 0.16), size: 150),
            ),
            SafeArea(
              child: ListView(
                padding: AppConstants.screenPadding,
                children: <Widget>[
                  const HomeHeader(),
                  const SizedBox(height: 22),
                  CustomTextField(
                    controller: _searchController,
                    hintText: 'Scan QR / Enter Join Code',
                    prefixIcon: Icons.qr_code_scanner_rounded,
                    onChanged: (String value) {
                      setState(() {
                        _query = value;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  _QuickStats(users.length),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Recommended Profiles',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        '${filteredUsers.length} matches',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...filteredUsers.map((UserModel user) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ProfileCard(
                        user: user,
                        onTap: () {
                          context.go('${AppRoutePaths.profile}?userId=${user.id}');
                        },
                        onPrimaryAction: () {
                          if (user.role == UserRole.alumni) {
                            context.go('${AppRoutePaths.profile}?userId=${user.id}');
                            return;
                          }

                          final List<ChatModel> chats = ref.read(mockChatsProvider);
                          final ChatModel? chat = chats.where((ChatModel entry) => entry.participantId == user.id).isNotEmpty
                              ? chats.firstWhere((ChatModel entry) => entry.participantId == user.id)
                              : null;
                          if (chat != null) {
                            context.go('${AppRoutePaths.chat}?chatId=${chat.id}');
                          } else {
                            context.go('${AppRoutePaths.profile}?userId=${user.id}');
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.24),
            AppColors.surface.withValues(alpha: 0.72),
          ],
        ),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.color,
    this.size = 180,
  });

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
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

