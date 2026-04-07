import 'dart:math' as math;

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
      final success = await ref
          .read(authNotifierProvider.notifier)
          .signInWithEmail(email, password);
      if (!success) {
        _showSnackBar(
          ref.read(authNotifierProvider).errorMessage ?? 'Sign in failed',
        );
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
      final success = await ref
          .read(authNotifierProvider.notifier)
          .signUpWithEmail(email, password);
      if (!success) {
        _showSnackBar(
          ref.read(authNotifierProvider).errorMessage ?? 'Sign up failed',
        );
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
      final success = await ref
          .read(authNotifierProvider.notifier)
          .signInWithSocial(provider);
      if (!success) {
        _showSnackBar(
          ref.read(authNotifierProvider).errorMessage ?? 'Sign in failed',
        );
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
              child: _GlowBlob(
                color: AppColors.accentCyan.withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: _GlowBlob(
                color: AppColors.accentBlue.withValues(alpha: 0.12),
                size: 200,
              ),
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
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3.0,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Secure identity. Infinite connection.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        _SocialAuthButton(
                          label: 'Continue with Apple',
                          leading: const Icon(
                            Icons.apple,
                            color: Colors.black,
                            size: 22,
                          ),
                          onPressed: _isLoading
                              ? null
                              : () => _handleSocialLogin(OAuthProvider.apple),
                        ),
                        const SizedBox(height: 12),
                        _SocialAuthButton(
                          label: 'Continue with Google',
                          leading: const _GoogleLogo(size: 20),
                          onPressed: _isLoading
                              ? null
                              : () => _handleSocialLogin(OAuthProvider.google),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'OR',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.56,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
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
                                onPressed: _isLoading
                                    ? () {}
                                    : _handleEmailSignUp,
                                filled: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomButton(
                                label: _isLoading ? '...' : 'Login',
                                icon: Icons.login_rounded,
                                onPressed: _isLoading
                                    ? () {}
                                    : _handleEmailLogin,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  // "Guest" logic skips to the generic setup profile
                                  context.push(AppRoutePaths.onboarding);
                                },
                          child: Text(
                            'Continue as Guest',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
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
        boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 10)],
      ),
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.label,
    required this.leading,
    this.onPressed,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: <Widget>[
                  SizedBox.square(dimension: 24, child: Center(child: leading)),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double strokeWidth = size.width * 0.18;
    final double radius = (size.width - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    void drawArc(Color color, double startDegrees, double sweepDegrees) {
      canvas.drawArc(
        rect,
        _radians(startDegrees),
        _radians(sweepDegrees),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    drawArc(const Color(0xFF4285F4), -40, 100);
    drawArc(const Color(0xFFDB4437), 55, 100);
    drawArc(const Color(0xFFF4B400), 155, 92);
    drawArc(const Color(0xFF0F9D58), 247, 68);

    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width * 0.88, center.dy),
      barPaint,
    );
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
