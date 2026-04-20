import 'package:flutter/material.dart';

class GracyAILogo extends StatelessWidget {
  const GracyAILogo({
    super.key,
    this.size = 64,
    this.glowing = false,
  });

  final double size;
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (glowing)
          Container(
            width: size * 1.3,
            height: size * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.cyan.withValues(alpha: 0.4), Colors.transparent],
              ),
            ),
          ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.cyan, Colors.indigo],
            ),
            boxShadow: glowing
                ? [BoxShadow(color: Colors.cyan.withValues(alpha: 0.5), blurRadius: 12)]
                : null,
          ),
          child: CustomPaint(
            painter: _GracyNeuralPainter(glowing),
          ),
        ),
      ],
    );
  }
}

class _GracyNeuralPainter extends CustomPainter {
  _GracyNeuralPainter(this.glowing);

  final bool glowing;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: glowing ? 1.0 : 0.9);

    final double center = size.width / 2;
    final double radius = size.width * 0.35;

    // Neural network core
    canvas.drawCircle(Offset(center, center), radius * 0.6, paint);

    // Outer ring
    canvas.drawCircle(Offset(center, center), radius, paint);

    // Neural connections
    final List<Offset> nodes = [
      Offset(center * 0.4, center * 0.3),
      Offset(center * 1.6, center * 0.3),
      Offset(center * 0.2, center * 1.7),
      Offset(center * 1.8, center * 1.7),
    ];

    for (final Offset node in nodes) {
      canvas.drawCircle(node, 4, paint);
      canvas.drawLine(node, Offset(center, center), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
