import 'package:flutter/material.dart';
import '../../chat/widgets/neural_background.dart';

class AuthSplashScreen extends StatefulWidget {
  const AuthSplashScreen({super.key});

  @override
  State<AuthSplashScreen> createState() => _AuthSplashScreenState();
}

class _AuthSplashScreenState extends State<AuthSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 0.94,
    end: 1.04,
  ).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Immersion AI Background
          NeuralBackground(
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (BuildContext context, Widget? child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildAnimatedLogo(),
                      const SizedBox(height: 32),
                      _buildAnimatedText(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Transform.scale(
      scale: _scaleAnimation.value,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Neural Orbit Rings
          ...List.generate(3, (index) {
            final double baseSize = 108.0 + (index * 40.0);
            return Container(
              width: baseSize * _scaleAnimation.value,
              height: baseSize * _scaleAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1 - (index * 0.03)),
                  width: 1.5,
                ),
              ),
            );
          }),
          
          // Outer Glow
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Main Logo Bubble
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: Color(0xFF007AFF),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedText() {
    return Column(
      children: [
        const Text(
          'GRACY',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 12,
            shadows: [
              Shadow(
                color: Colors.white24,
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Powered by NexaGen',
          style: TextStyle(
            color: const Color(0xFF007AFF).withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
