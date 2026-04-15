import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/premium_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/user_avatar.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? currentUser = ref.watch(resolvedCurrentUserProvider);
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String activeTheme = ref.watch(themeProvider);
    final bool isGuest =
        SupabaseConfig.isConfigured &&
        Supabase.instance.client.auth.currentUser?.isAnonymous == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), scrolledUnderElevation: 0),
      body: ListView(
        padding: AppConstants.screenPadding,
        children: <Widget>[
          if (isGuest) ...[
            _buildGuestWarning(context),
            const SizedBox(height: 16),
          ],
          _buildProfileSection(context, currentUser),
          const SizedBox(height: 32),
          _buildThemeSection(context, ref, activeTheme),
          const SizedBox(height: 32),
          _buildPreferencesSection(context, ref, currentUser),
          const SizedBox(height: 48),
          _buildDangerZone(context, ref),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildGuestWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest account',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign up to save your progress!',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, UserModel user) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            UserAvatar(user: user, size: 60, fontSize: 18),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.username,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (user.gracyId != null) ...<Widget>[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: user.gracyId!),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gracy ID copied to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user.gracyId!,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        EditProfileScreen(user: user),
                  ),
                );
              },
              tooltip: 'Edit Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection(
    BuildContext context,
    WidgetRef ref,
    String activeTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'App Theme',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: <Widget>[
              _ThemeCard(
                name: 'Midnight',
                themeKey: 'midnight',
                primaryColor: const Color(0xFF00E5FF),
                backgroundColor: const Color(0xFF0B0F19),
                isActive: activeTheme == 'midnight',
                onTap: () =>
                    ref.read(themeProvider.notifier).setTheme('midnight'),
              ),
              const SizedBox(width: 12),
              _ThemeCard(
                name: 'Sunset',
                themeKey: 'sunset',
                primaryColor: const Color(0xFFFF7B54),
                backgroundColor: const Color(0xFF1C1326),
                isActive: activeTheme == 'sunset',
                onTap: () =>
                    ref.read(themeProvider.notifier).setTheme('sunset'),
              ),
              const SizedBox(width: 12),
              _ThemeCard(
                name: 'Forest',
                themeKey: 'forest',
                primaryColor: const Color(0xFF00E676),
                backgroundColor: const Color(0xFF0B1A14),
                isActive: activeTheme == 'forest',
                onTap: () =>
                    ref.read(themeProvider.notifier).setTheme('forest'),
              ),
              const SizedBox(width: 12),
              _ThemeCard(
                name: 'Classic',
                themeKey: 'classic',
                primaryColor: const Color(0xFF5DE4C7),
                backgroundColor: const Color(0xFF08111F),
                isActive: activeTheme == 'classic',
                onTap: () =>
                    ref.read(themeProvider.notifier).setTheme('classic'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    final bool isGhostMode = ref.watch(ghostModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).dividerTheme.color ?? Colors.grey,
              width: 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              _settingItem(
                context,
                icon: Icons.notifications_rounded,
                iconColor: Colors.red,
                title: 'Notifications',
                subtitle: 'Push alerts & messages',
                trailing: Switch(
                  value: user.notificationsEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool val) {
                    ref.read(themeProvider.notifier).updateNotifications(val);
                  },
                ),
                onTap: null,
              ),
              const Divider(height: 1),
              _settingItem(
                context,
                icon: Icons.visibility_rounded,
                iconColor: Colors.blue,
                title: 'Ghost Mode',
                subtitle: 'Hide your online status from others',
                trailing: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isGhostMode,
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                      onChanged: (bool val) {
                        ref.read(themeProvider.notifier).updateGhostMode(val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              val
                                  ? 'Ghost Mode enabled'
                                  : 'Ghost Mode disabled',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: null,
              ),
              const Divider(height: 1),
              _settingItem(
                context,
                icon: Icons.timer_rounded,
                iconColor: Colors.green,
                title: 'Disappearing Messages',
                subtitle: 'Set messages to disappear after viewing',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () {
                  // Show disappearing messages dialog
                },
              ),
              const Divider(height: 1),
              _settingItem(
                context,
                icon: Icons.star_rounded,
                iconColor: Colors.amber,
                title: 'Premium',
                subtitle: 'Unlock all premium features',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  ref.read(premiumServiceProvider).showPremiumDialog(context);
                },
              ),
              const Divider(height: 1),
              _settingItem(
                context,
                icon: Icons.privacy_tip_rounded,
                iconColor: Colors.purple,
                title: 'Privacy',
                subtitle: 'Manage your privacy settings',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  // Navigate to privacy settings
                },
              ),
              const Divider(height: 1),
              _settingItem(
                context,
                icon: Icons.security_rounded,
                iconColor: Colors.orange,
                title: 'Security',
                subtitle: 'Account security and authentication',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  // Navigate to security settings
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[trailing],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context, WidgetRef ref) {
    final Color dangerBorder = const Color(0xFF7A2A2A).withValues(alpha: 0.48);
    final Color dangerSurface = const Color(0xFF561313).withValues(alpha: 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Danger Zone',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: dangerSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dangerBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Center(
                  child: SizedBox(
                    width: 240,
                    child: CustomButton(
                      label: 'Logout',
                      icon: Icons.logout_rounded,
                      filled: false,
                      fullWidth: true,
                      onPressed: () {
                        ref.read(authNotifierProvider.notifier).logout();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 240,
                    child: CustomButton(
                      label: 'Delete Account',
                      icon: Icons.delete_forever_rounded,
                      filled: false,
                      fullWidth: true,
                      onPressed: () => _showDeleteDialog(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Are you sure?'),
          content: const Text(
            'This action is permanent and cannot be undone. All your data will be permanently deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    content: const Text('Account deletion requested. (Demo)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.name,
    required this.themeKey,
    required this.primaryColor,
    required this.backgroundColor,
    required this.isActive,
    required this.onTap,
  });

  final String name;
  final String themeKey;
  final Color primaryColor;
  final Color backgroundColor;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 110,
        height: 140,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? primaryColor : AppColors.outline,
            width: isActive ? 2.5 : 1,
          ),
          boxShadow: isActive
              ? <BoxShadow>[
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor, width: 3),
              ),
              child: isActive
                  ? Icon(Icons.check_rounded, color: primaryColor, size: 20)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
