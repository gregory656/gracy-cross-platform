import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EliteAnimations {
  EliteAnimations._();

  // Message send animation
  static Widget messageSendAnimation({
    required Widget child,
    required AnimationController controller,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + (controller.value * 0.1);
        final opacity = 1.0 - (controller.value * 0.3);
        
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Status tick animation
  static Widget statusTickAnimation({
    required Widget child,
    required AnimationController controller,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final rotation = controller.value * 0.1;
        final scale = 0.8 + (controller.value * 0.2);
        
        return Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Button press animation
  static Widget buttonPressAnimation({
    required Widget child,
    required AnimationController controller,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 - (controller.value * 0.05);
        
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: child,
    );
  }

  // Slide in animation
  static Widget slideInAnimation({
    required Widget child,
    required AnimationController controller,
    SlideDirection direction = SlideDirection.up,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        Offset begin;
        switch (direction) {
          case SlideDirection.up:
            begin = const Offset(0, 0.3);
            break;
          case SlideDirection.down:
            begin = const Offset(0, -0.3);
            break;
          case SlideDirection.left:
            begin = const Offset(0.3, 0);
            break;
          case SlideDirection.right:
            begin = const Offset(-0.3, 0);
            break;
        }
        
        final offset = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        ));
        
        final opacity = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
        ));
        
        return SlideTransition(
          position: offset,
          child: FadeTransition(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

enum SlideDirection { up, down, left, right }

// Haptic feedback utilities
class EliteHaptics {
  EliteHaptics._();

  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  static void notificationSuccess() {
    HapticFeedback.lightImpact(); // Fallback for older Flutter versions
  }

  static void notificationWarning() {
    HapticFeedback.mediumImpact(); // Fallback for older Flutter versions
  }

  static void notificationError() {
    HapticFeedback.heavyImpact(); // Fallback for older Flutter versions
  }
}

// Animated button with haptic feedback
class EliteAnimatedButton extends StatefulWidget {
  const EliteAnimatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.hapticType = HapticType.light,
    this.duration = const Duration(milliseconds: 150),
  });

  final VoidCallback onPressed;
  final Widget child;
  final HapticType hapticType;
  final Duration duration;

  @override
  State<EliteAnimatedButton> createState() => _EliteAnimatedButtonState();
}

class _EliteAnimatedButtonState extends State<EliteAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _triggerHapticFeedback();
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onPressed();
  }

  void _triggerHapticFeedback() {
    switch (widget.hapticType) {
      case HapticType.light:
        EliteHaptics.lightImpact();
        break;
      case HapticType.medium:
        EliteHaptics.mediumImpact();
        break;
      case HapticType.heavy:
        EliteHaptics.heavyImpact();
        break;
      case HapticType.selection:
        EliteHaptics.selectionClick();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: EliteAnimations.buttonPressAnimation(
        controller: _controller,
        child: widget.child,
      ),
    );
  }
}

enum HapticType { light, medium, heavy, selection }

// Message status tick widget with animation
class AnimatedStatusTicks extends StatefulWidget {
  const AnimatedStatusTicks({
    super.key,
    required this.status,
    this.size = 14,
  });

  final MessageStatus status;
  final double size;

  @override
  State<AnimatedStatusTicks> createState() => _AnimatedStatusTicksState();
}

class _AnimatedStatusTicksState extends State<AnimatedStatusTicks>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedStatusTicks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: _buildStatusTicks(),
        );
      },
    );
  }

  Widget _buildStatusTicks() {
    final color = _getStatusColor();
    final icons = _getStatusIcons();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons.map((icon) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            icon,
            size: widget.size,
            color: color,
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case MessageStatus.sent:
        return const Color(0xFF8E8E93);
      case MessageStatus.delivered:
        return const Color(0xFF8E8E93);
      case MessageStatus.read:
        return const Color(0xFF30D158);
    }
  }

  List<IconData> _getStatusIcons() {
    switch (widget.status) {
      case MessageStatus.sent:
        return [Icons.done];
      case MessageStatus.delivered:
        return [Icons.done_all];
      case MessageStatus.read:
        return [Icons.done_all];
    }
  }
}

// Import for MessageStatus
enum MessageStatus { sent, delivered, read }

// Import for HapticFeedbackType
enum HapticFeedbackType { success, warning, error }
