import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/utils/gracy_id.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_card.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  int _currentPage = 0;
  bool _privacyShown = false;
  final String _gracyId = generateGracyId();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_privacyShown) {
        _privacyShown = true;
        _showPrivacyShield();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _showPrivacyShield() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Privacy Shield'),
          content: const Text(
            'Gracy never stores your messages in the cloud. Everything stays on your physical phone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _goToPage(int page) async {
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _copyId() async {
    await Clipboard.setData(ClipboardData(text: _gracyId));
    _showSnackBar('Ghost passcode copied.');
  }

  Future<void> _shareId() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            "You've been invited to the ghost realm. Find me: $_gracyId. "
            "Try not to wake the mortals.",
      ),
    );
  }

  Future<void> _enterGracy() async {
    final String username = _usernameController.text.trim();
    final String fullName = _fullNameController.text.trim();
    final String bio = _bioController.text.trim();
    final String year = _yearController.text.trim();

    if (username.isEmpty) {
      _showSnackBar('Username is required before the gate opens.');
      return;
    }

    final bool success = await ref
        .read(authNotifierProvider.notifier)
        .completeOnboarding(
          username: username,
          fullName: fullName,
          bio: bio,
          yearOfStudy: year,
          gracyId: _gracyId,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      debugPrint('Onboarding complete, routing to home.');
      context.go(AppRoutePaths.home);
      return;
    }

    final String message =
        ref.read(authNotifierProvider).errorMessage ??
        'Sign up failed. Try again.';
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.background,
              AppColors.backgroundAlt,
              Color(0xFF081C2E),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -50,
              right: -30,
              child: _GlowBlob(
                color: AppColors.accentCyan.withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              top: 140,
              left: -20,
              child: _GlowBlob(
                color: AppColors.accentBlue.withValues(alpha: 0.16),
                size: 140,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: AppConstants.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'GRACY',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Private identity first. Everything else follows.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _StepDots(currentPage: _currentPage),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (int index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        children: <Widget>[
                          _AuthStepCard(
                            title: 'The Lock',
                            subtitle: 'Mandatory auth. No keys, no door.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const _OptionalBadge(label: 'Required'),
                                const SizedBox(height: 14),
                                CustomTextField(
                                  controller: _usernameController,
                                  hintText: 'Username',
                                  prefixIcon: Icons.alternate_email_rounded,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'This uses anonymous Supabase auth. Your username is stored as profile metadata only.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _AuthStepCard(
                            title: 'The Persona',
                            subtitle:
                                'Optional details that make your profile feel alive.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const _OptionalBadge(label: 'Optional'),
                                const SizedBox(height: 14),
                                CustomTextField(
                                  controller: _fullNameController,
                                  hintText: 'Full Name',
                                  prefixIcon: Icons.badge_rounded,
                                ),
                                const SizedBox(height: 14),
                                CustomTextField(
                                  controller: _bioController,
                                  hintText:
                                      'Tell us a secret... or just your favorite pizza topping. We will not judge.',
                                  prefixIcon: Icons.edit_note_rounded,
                                  keyboardType: TextInputType.multiline,
                                  maxLines: 3,
                                  height: 92,
                                ),
                                const SizedBox(height: 14),
                                CustomTextField(
                                  controller: _yearController,
                                  hintText: 'Year of Study',
                                  prefixIcon: Icons.school_rounded,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Skip anything you want. The only required part is the lock on screen one.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _AuthStepCard(
                            title: 'The Reveal',
                            subtitle: 'Your private identity code is ready.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: AppColors.outline,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: <Color>[
                                        AppColors.accentCyan.withValues(
                                          alpha: 0.20,
                                        ),
                                        AppColors.accentBlue.withValues(
                                          alpha: 0.12,
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Gracy ID',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              letterSpacing: 1.2,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _gracyId,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.8,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'This code is the mask. Keep it close.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: CustomButton(
                                        label: 'Copy',
                                        icon: Icons.copy_rounded,
                                        filled: false,
                                        onPressed: _copyId,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomButton(
                                        label: 'Share',
                                        icon: Icons.share_rounded,
                                        filled: false,
                                        onPressed: _shareId,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Want the funny version? Your invite is already tuned for ghost-mode sharing.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        if (_currentPage > 0)
                          Expanded(
                            child: CustomButton(
                              label: 'Back',
                              icon: Icons.arrow_back_rounded,
                              filled: false,
                              onPressed: () => _goToPage(_currentPage - 1),
                            ),
                          ),
                        if (_currentPage > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _currentPage < 2
                              ? CustomButton(
                                  label: _currentPage == 0 ? 'Next' : 'Reveal',
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: () => _goToPage(_currentPage + 1),
                                )
                              : CustomButton(
                                  label: authState.isLoading
                                      ? 'Entering...'
                                      : 'Enter Gracy',
                                  icon: authState.isLoading
                                      ? Icons.hourglass_top_rounded
                                      : Icons.login_rounded,
                                  onPressed: authState.isLoading
                                      ? () {}
                                      : _enterGracy,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthStepCard extends StatelessWidget {
  const _AuthStepCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionalBadge extends StatelessWidget {
  const _OptionalBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.accentCyan.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.accentCyan,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(3, (int index) {
        final bool active = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
          width: active ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accentCyan
                : AppColors.textSecondary.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
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
