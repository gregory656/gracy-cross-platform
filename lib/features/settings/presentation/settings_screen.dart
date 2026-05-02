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

final ValueNotifier<bool> settingsStatusVisibleNotifier =
    ValueNotifier<bool>(true);
final ValueNotifier<bool> settingsReadReceiptsNotifier =
    ValueNotifier<bool>(true);
final ValueNotifier<bool> settingsMapPrivacyNotifier =
    ValueNotifier<bool>(false);
final ValueNotifier<bool> settingsGroupPrivacyNotifier =
    ValueNotifier<bool>(true);
final ValueNotifier<bool> settingsConfessionsPrivateNotifier =
    ValueNotifier<bool>(true);
final ValueNotifier<bool> settingsBiometricsNotifier =
    ValueNotifier<bool>(false);
final ValueNotifier<bool> settingsWifiDownloadNotifier =
    ValueNotifier<bool>(true);
final ValueNotifier<bool> settingsCellularDownloadNotifier =
    ValueNotifier<bool>(false);
final ValueNotifier<bool> settingsCampusDataSaverNotifier =
    ValueNotifier<bool>(false);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? currentUser = ref.watch(resolvedCurrentUserProvider);
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isGuest =
        SupabaseConfig.isConfigured &&
        Supabase.instance.client.auth.currentUser?.isAnonymous == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Gracy Settings'), scrolledUnderElevation: 0),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: AppConstants.screenPadding,
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(<Widget>[
                if (isGuest) ...<Widget>[
                  _buildGuestWarning(context),
                  const SizedBox(height: 16),
                ],
                _buildProfileSection(context, currentUser),
                const SizedBox(height: 16),
                _buildPremiumBanner(context, ref),
                const SizedBox(height: 24),
                _settingsGroup(
                  context,
                  title: 'Profile',
                  children: <Widget>[
                    _settingItem(
                      context,
                      icon: Icons.account_circle_rounded,
                      iconColor: AppColors.electricBlue,
                      title: 'Avatar & Status',
                      subtitle: 'Update your photo, display name, and campus presence',
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                EditProfileScreen(user: currentUser),
                          ),
                        );
                      },
                    ),
                    _notifierSwitchItem(
                      context,
                      notifier: settingsStatusVisibleNotifier,
                      icon: Icons.wifi_tethering_rounded,
                      iconColor: Colors.green,
                      title: 'Status Visibility',
                      subtitle: 'Show when you are active on Gracy',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _settingsGroup(
                  context,
                  title: 'Privacy',
                  children: <Widget>[
                    _notifierSwitchItem(
                      context,
                      notifier: settingsReadReceiptsNotifier,
                      icon: Icons.done_all_rounded,
                      iconColor: Colors.blue,
                      title: 'Read Receipts',
                      subtitle: "If turned off, you won't see receipts from others.",
                    ),
                    _notifierSwitchItem(
                      context,
                      notifier: settingsMapPrivacyNotifier,
                      icon: Icons.map_rounded,
                      iconColor: Colors.teal,
                      title: 'Map Privacy',
                      subtitle: 'Hide Last Seen on Campus Map.',
                    ),
                    _notifierSwitchItem(
                      context,
                      notifier: settingsGroupPrivacyNotifier,
                      icon: Icons.groups_rounded,
                      iconColor: Colors.purple,
                      title: 'Groups Privacy Management',
                      subtitle: 'Control who can add you to campus groups',
                    ),
                    _notifierSwitchItem(
                      context,
                      notifier: settingsConfessionsPrivateNotifier,
                      icon: Icons.lock_person_rounded,
                      iconColor: Colors.indigo,
                      title: 'Strictly Private Confessions',
                      subtitle: 'Keep confession activity anonymous',
                    ),
                    _settingItem(
                      context,
                      icon: Icons.delete_forever_rounded,
                      iconColor: Theme.of(context).colorScheme.error,
                      title: 'Delete Account',
                      subtitle: 'Permanently remove your Gracy account',
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () => _showDeleteDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _settingsGroup(
                  context,
                  title: 'Security',
                  children: <Widget>[
                    _notifierSwitchItem(
                      context,
                      notifier: settingsBiometricsNotifier,
                      icon: Icons.fingerprint_rounded,
                      iconColor: Colors.orange,
                      title: 'Biometrics',
                      subtitle: 'Use device biometrics to protect Gracy',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _settingsGroup(
                  context,
                  title: 'Network & Data',
                  children: <Widget>[
                    const _DataUsageTile(),
                    _notifierSwitchItem(
                      context,
                      notifier: settingsWifiDownloadNotifier,
                      icon: Icons.wifi_rounded,
                      iconColor: Colors.green,
                      title: 'Auto-download on Wi-Fi',
                      subtitle: 'Download campus media on trusted networks',
                    ),
                    _notifierSwitchItem(
                      context,
                      notifier: settingsCellularDownloadNotifier,
                      icon: Icons.network_cell_rounded,
                      iconColor: Colors.red,
                      title: 'Auto-download on Cellular',
                      subtitle: 'Keep mobile data protected by default',
                    ),
                    _notifierSwitchItem(
                      context,
                      notifier: settingsCampusDataSaverNotifier,
                      icon: Icons.speed_rounded,
                      iconColor: Colors.cyan,
                      title: 'Campus Data Saver',
                      subtitle: 'Compress campus-feed media before loading',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _settingsGroup(
                  context,
                  title: 'Chat & Notifications',
                  children: <Widget>[
                    _settingItem(
                      context,
                      icon: Icons.notifications_rounded,
                      iconColor: Colors.red,
                      title: 'Notifications',
                      subtitle: 'Direct messages, mentions, sounds, and vibration',
                      trailing: Switch(
                        value: currentUser.notificationsEnabled,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (bool val) {
                          ref.read(themeProvider.notifier).updateNotifications(val);
                        },
                      ),
                      onTap: null,
                    ),
                    const _TextScalePreviewTile(),
                    _settingItem(
                      context,
                      icon: Icons.music_note_rounded,
                      iconColor: Colors.amber,
                      title: 'Custom Academic Ringtones',
                      subtitle: 'University Bell',
                      trailing: const Icon(Icons.arrow_drop_down_rounded),
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _settingsGroup(
                  context,
                  title: 'Support, FAQ, & About',
                  children: <Widget>[
                    _settingItem(
                      context,
                      icon: Icons.search_rounded,
                      iconColor: Colors.blueGrey,
                      title: 'Search FAQ',
                      subtitle: 'Academic FAQ, Faculty contact, and diagnostic logs',
                      trailing: const Icon(Icons.share_rounded, size: 18),
                      onTap: null,
                    ),
                    _settingItem(
                      context,
                      icon: Icons.info_rounded,
                      iconColor: Colors.lightBlue,
                      title: 'About Gracy',
                      subtitle: 'Version history: 1.1.0, 1.3.0, 1.3.3, 2.2.0',
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: null,
                    ),
                    _settingItem(
                      context,
                      icon: Icons.gavel_rounded,
                      iconColor: Colors.grey,
                      title: 'Legal',
                      subtitle: 'EULA, Legal Links, and Privacy Links',
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildDangerZone(context, ref),
                const SizedBox(height: 120),
              ]),
            ),
          ),
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

  // ignore: unused_element
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

  Widget _buildPremiumBanner(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ref.read(premiumServiceProvider).showPremiumDialog(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF101827), Color(0xFF172554)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.diamond_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Gracy Premium (Not Subscribed)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ad-free campus feed, analytics, stickers, and student status.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsGroup(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).dividerTheme.color ?? Colors.grey,
            ),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                children[i],
                if (i != children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _notifierSwitchItem(
    BuildContext context, {
    required ValueNotifier<bool> notifier,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (BuildContext context, bool value, Widget? child) {
        return _settingItem(
          context,
          icon: icon,
          iconColor: iconColor,
          title: title,
          subtitle: subtitle,
          trailing: Switch(
            value: value,
            activeThumbColor: Theme.of(context).colorScheme.primary,
            onChanged: (bool nextValue) {
              notifier.value = nextValue;
            },
          ),
          onTap: () {
            notifier.value = !notifier.value;
          },
        );
      },
    );
  }

  // ignore: unused_element
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

class _DataUsageTile extends StatelessWidget {
  const _DataUsageTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 58,
            height: 58,
            child: CustomPaint(painter: _DonutUsagePainter()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Campus Media Usage',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '68% campus media, 32% personal data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.62),
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

class _DonutUsagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint basePaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final Paint mediaPaint = Paint()
      ..color = AppColors.electricBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 6.283, false, basePaint);
    canvas.drawArc(rect, -1.57, 6.283 * 0.68, false, mediaPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TextScalePreviewTile extends StatefulWidget {
  const _TextScalePreviewTile();

  @override
  State<_TextScalePreviewTile> createState() => _TextScalePreviewTileState();
}

class _TextScalePreviewTileState extends State<_TextScalePreviewTile> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Campus chat preview',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15 * _scale,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Slider(
            value: _scale,
            min: 0.85,
            max: 1.3,
            divisions: 9,
            label: '${(_scale * 100).round()}%',
            onChanged: (double value) {
              setState(() {
                _scale = value;
              });
            },
          ),
        ],
      ),
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
