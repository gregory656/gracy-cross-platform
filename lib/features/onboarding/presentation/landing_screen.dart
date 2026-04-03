import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_card.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Email and password are required.');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await ref.read(authNotifierProvider.notifier).signInWithEmail(email, password);
      if (!success) {
        _showSnackBar(ref.read(authNotifierProvider).errorMessage ?? 'Sign in failed');
      } else {
        _checkProfileNavigation();
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Email and password are required.');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await ref.read(authNotifierProvider.notifier).signUpWithEmail(email, password);
      if (!success) {
        _showSnackBar(ref.read(authNotifierProvider).errorMessage ?? 'Sign up failed');
      } else {
        _checkProfileNavigation();
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialLogin(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authNotifierProvider.notifier).signInWithSocial(provider);
      if (!success) {
        _showSnackBar(ref.read(authNotifierProvider).errorMessage ?? 'Sign in failed');
      } else {
         // Social login usually redirects to browser, so we wait for deep link.
         // In this demo, we assume the bootstrap handles returning state.
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkProfileNavigation() {
    // Rely on router redirect logic, or navigate explicitly if needed.
    final authState = ref.read(authNotifierProvider);
    if (!authState.isOnboardingComplete) {
      context.go(AppRoutePaths.onboarding);
    } else {
      context.go(AppRoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.backgroundAlt,
              Color(0xFF081C2E),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -50,
              child: _GlowBlob(color: AppColors.accentCyan.withValues(alpha: 0.15)),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: _GlowBlob(color: AppColors.accentBlue.withValues(alpha: 0.12), size: 200),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: AppConstants.screenPadding,
                  physics: const BouncingScrollPhysics(),
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'GRACY',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Secure identity. Infinite connection.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        
                        CustomButton(
                          label: 'Continue with Apple',
                          icon: Icons.apple,
                          onPressed: _isLoading ? () {} : () => _handleSocialLogin(OAuthProvider.apple),
                          fullWidth: true,
                        ),
                        const SizedBox(height: 12),
                        CustomButton(
                          label: 'Continue with Google',
                          icon: Icons.g_mobiledata_rounded,
                          onPressed: _isLoading ? () {} : () => _handleSocialLogin(OAuthProvider.google),
                          fullWidth: true,
                          filled: false,
                        ),
                        
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppColors.outline)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: AppColors.outline)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        CustomTextField(
                          controller: _emailController,
                          hintText: 'Email address',
                          prefixIcon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          prefixIcon: Icons.lock_rounded,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                label: _isLoading ? '...' : 'Sign Up',
                                icon: Icons.person_add_rounded,
                                onPressed: _isLoading ? () {} : _handleEmailSignUp,
                                filled: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomButton(
                                label: _isLoading ? '...' : 'Login',
                                icon: Icons.login_rounded,
                                onPressed: _isLoading ? () {} : _handleEmailLogin,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            // "Guest" logic skips to the generic setup profile
                            context.push(AppRoutePaths.onboarding);
                          },
                          child: Text(
                            'Continue as Guest',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        boxShadow: [
          BoxShadow(color: color, blurRadius: 40, spreadRadius: 10),
        ],
      ),
    );
  }
}
