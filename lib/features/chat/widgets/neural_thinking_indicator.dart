import 'dart:math' as math;
import 'package:flutter/material.dart';

class NeuralThinkingIndicator extends StatefulWidget {
  const NeuralThinkingIndicator({super.key});

  @override
  State<NeuralThinkingIndicator> createState() => _NeuralThinkingIndicatorState();
}

class _NeuralThinkingIndicatorState extends State<NeuralThinkingIndicator>
    with TickerProviderStateMixin {
  static const Color _electricBlue = Color(0xFF007AFF);
  
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  
  late Animation<double> _orbitAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Orbit animation (circular motion)
    _orbitController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    // Pulse animation (scale in/out)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Shimmer animation (moving highlight)
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _orbitAnimation = Tween<double>(begin: 0, end: math.pi * 2).animate(_orbitController);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(_shimmerController);
  }
  
  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 14),
      constraints: const BoxConstraints(maxHeight: 52),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Avatar with orbit effect
          _buildOrbitingAvatar(),
          
          const SizedBox(width: 12),
          
          // Thinking bubble with shimmer
          Expanded(
            child: _buildShimmeringBubble(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbitingAvatar() {
    return AnimatedBuilder(
      animation: _orbitAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Orbit rings
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _electricBlue.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value * 0.8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _electricBlue.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Central avatar
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A1D29),
                  border: Border.all(
                    color: _electricBlue,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _electricBlue.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: _electricBlue,
                  size: 12,
                ),
              ),
              
              // Orbiting dots
              ...List.generate(3, (index) {
                final angle = _orbitAnimation.value + (index * math.pi * 2 / 3);
                final radius = 20.0;
                final x = math.cos(angle) * radius;
                final y = math.sin(angle) * radius;
                
                return Positioned(
                  left: 24 + x - 2,
                  top: 24 + y - 2,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _electricBlue.withValues(alpha: 0.6),
                      boxShadow: [
                        BoxShadow(
                          color: _electricBlue.withValues(alpha: 0.8),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmeringBubble() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D29).withValues(alpha: 0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(
                color: _electricBlue.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(22),
              ),
              child: Stack(
                children: [
                  // Base text
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(right: 60),
                    child: Text(
                      'GracyAI is thinking',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  
                  // Shimmer overlay
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(22),
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.transparent,
                            _electricBlue.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                          stops: [_shimmerAnimation.value, _shimmerAnimation.value + 0.1, _shimmerAnimation.value + 0.2],
                        ).createShader(bounds),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _electricBlue.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Dots animation
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final delay = index * 0.2;
                              final animationValue = (_pulseController.value + delay) % 1.0;
                              final opacity = animationValue > 0.3 && animationValue < 0.7 ? 1.0 : 0.3;
                              
                              return Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _electricBlue.withValues(alpha: opacity),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
