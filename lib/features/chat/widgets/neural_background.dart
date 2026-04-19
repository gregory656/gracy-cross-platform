import 'dart:math' as math;
import 'package:flutter/material.dart';

class NeuralBackground extends StatefulWidget {
  const NeuralBackground({super.key, required this.child});
  
  final Widget child;

  @override
  State<NeuralBackground> createState() => _NeuralBackgroundState();
}

class _NeuralBackgroundState extends State<NeuralBackground>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _meshController;
  
  @override
  void initState() {
    super.initState();
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _meshController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
  }
  
  @override
  void dispose() {
    _particleController.dispose();
    _meshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Neural gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0E1A), // Deep Navy
                Color(0xFF050711), // Near Black
                Color(0xFF000000), // Pure Black
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        
        // Animated mesh overlay
        AnimatedBuilder(
          animation: _meshController,
          builder: (context, child) {
            return CustomPaint(
              painter: _MeshPainter(_meshController.value),
              size: Size.infinite,
            );
          },
        ),
        
        // Floating particles
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            return CustomPaint(
              painter: _ParticlePainter(_particleController.value),
              size: Size.infinite,
            );
          },
        ),
        
        // Content overlay
        widget.child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.animation);
  
  final double animation;
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final time = animation * math.pi * 2;
    
    // Create flowing mesh pattern
    for (int i = 0; i < 5; i++) {
      final offsetX = math.sin(time + i * 0.5) * 100;
      final offsetY = math.cos(time + i * 0.3) * 50;
      
      final centerX = size.width / 2 + offsetX;
      final centerY = size.height / 2 + offsetY;
      
      path.addOval(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: 200 + math.sin(time + i) * 50,
          height: 200 + math.cos(time + i) * 50,
        ),
      );
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.animation);
  
  final double animation;
  
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 20; i++) {
      final progress = (i / 20.0) + animation;
      final x = (math.sin(progress * math.pi * 2) * 0.5 + 0.5) * size.width;
      final y = (progress * 2.0) % 1.0 * size.height;
      
      final opacity = (math.sin(progress * math.pi * 2) * 0.5 + 0.5) * 0.3;
      final particleSize = 2.0 + math.sin(progress * math.pi * 4) * 1.0;
      
      final paint = Paint()
        ..color = Colors.cyan.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
