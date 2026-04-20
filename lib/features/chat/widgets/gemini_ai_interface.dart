import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/elite_animations.dart';
import 'gracy_ai_logo.dart';

class GeminiAIInterface extends StatefulWidget {
  const GeminiAIInterface({
    super.key,
    required this.onSendMessage,
    this.isEmpty = true,
  });

  final VoidCallback? onSendMessage;
  final bool isEmpty;

  @override
  State<GeminiAIInterface> createState() => _GeminiAIInterfaceState();
}

class _GeminiAIInterfaceState extends State<GeminiAIInterface>
    with TickerProviderStateMixin {
  static const List<String> _suggestedPrompts = [
    'Summarize my notes',
    'Coding help',
    'Campus events',
    'Study tips',
    'Project ideas',
    'Career advice',
  ];

  late AnimationController _glowController;
  late AnimationController _floatController;
  late Animation<double> _glowAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _handlePromptTap(String prompt) {
    EliteHaptics.mediumImpact();
    // 
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.95),
            Colors.black,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          
          // Animated Gracy Logo with Neural Glow
          AnimatedBuilder(
            animation: Listenable.merge([_glowAnimation, _floatAnimation]),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      // Electric Blue glow
                      BoxShadow(
                        color: AppColors.electricBlue.withValues(
                          alpha: _glowAnimation.value * 0.6,
                        ),
                        blurRadius: 40 * _glowAnimation.value,
                        spreadRadius: 8,
                      ),
                      // Neural Purple glow
                      BoxShadow(
                        color: const Color(0xFF6B46C1).withValues(
                          alpha: _glowAnimation.value * 0.4,
                        ),
                        blurRadius: 30 * _glowAnimation.value,
                        spreadRadius: 4,
                      ),
                      // Inner glow
                      BoxShadow(
                        color: AppColors.electricBlue.withValues(
                          alpha: _glowAnimation.value * 0.8,
                        ),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: GracyAILogo(
                    size: 120,
                    glowing: false, // We handle glow manually
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Welcome text
          Text(
            'Hello! I\'m GracyAI',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Your intelligent campus companion',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.2,
            ),
          ),
          
          const Spacer(flex: 1),
          
          // Suggested Prompts
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Try asking me:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestedPrompts.map((prompt) {
                    return _SuggestedPromptChip(
                      prompt: prompt,
                      onTap: () => _handlePromptTap(prompt),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SuggestedPromptChip extends StatefulWidget {
  const _SuggestedPromptChip({
    required this.prompt,
    required this.onTap,
  });

  final String prompt;
  final VoidCallback onTap;

  @override
  State<_SuggestedPromptChip> createState() => _SuggestedPromptChipState();
}

class _SuggestedPromptChipState extends State<_SuggestedPromptChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.electricBlue.withValues(alpha: 0.1),
                    AppColors.electricBlue.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.electricBlue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                widget.prompt,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.electricBlue,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
