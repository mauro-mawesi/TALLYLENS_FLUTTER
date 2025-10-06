import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/theme/circular_reveal_clipper.dart';
import 'package:recibos_flutter/core/theme/theme_controller.dart';

/// Overlay que muestra la animación circular de transición de tema
class ThemeRevealOverlay extends StatefulWidget {
  final ThemeController controller;
  final Widget child;

  const ThemeRevealOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<ThemeRevealOverlay> createState() => _ThemeRevealOverlayState();
}

class _ThemeRevealOverlayState extends State<ThemeRevealOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );

    widget.controller.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onThemeChange);
    _animationController.dispose();
    super.dispose();
  }

  void _onThemeChange() {
    if (widget.controller.isAnimating) {
      _animationController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (!widget.controller.isAnimating) {
          return const SizedBox.shrink();
        }

        final screenSize = MediaQuery.of(context).size;
        final center = widget.controller.tapPosition ?? Offset(screenSize.width / 2, 0);
        final maxRadius = calculateMaxRadius(screenSize, center);

        return Positioned.fill(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return ClipPath(
                clipper: CircularRevealClipper(
                  center: center,
                  radius: maxRadius * _animation.value,
                ),
                child: widget.child,
              );
            },
          ),
        );
      },
    );
  }
}
