import 'package:flutter/material.dart';
import 'dart:math' as math;

class HeroSearchBar extends StatefulWidget {
  final String hintText;
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;
  final String? filterTooltip;
  final TextEditingController? controller;

  const HeroSearchBar({
    super.key,
    required this.hintText,
    this.onTap,
    this.onFilterTap,
    this.filterTooltip,
    this.controller,
  });

  @override
  State<HeroSearchBar> createState() => _HeroSearchBarState();
}

class _HeroSearchBarState extends State<HeroSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPressed ? 0.98 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          colorScheme.surface.withOpacity(0.9),
                          colorScheme.surface.withOpacity(0.7),
                        ]
                      : [
                          Colors.white.withOpacity(0.95),
                          Colors.white.withOpacity(0.85),
                        ],
                ),
                border: Border.all(
                  width: 1.5,
                  color: Color.lerp(
                    isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                    colorScheme.primary.withOpacity(0.3),
                    _glowAnimation.value,
                  )!,
                ),
                boxShadow: [
                  // Primary glow shadow
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(
                      0.15 + (_glowAnimation.value * 0.1),
                    ),
                    blurRadius: 20 + (_glowAnimation.value * 5),
                    offset: const Offset(0, 8),
                    spreadRadius: _isPressed ? -2 : 0,
                  ),
                  // Soft elevation shadow
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: _isPressed ? 12 : 16,
                    offset: Offset(0, _isPressed ? 4 : 6),
                    spreadRadius: _isPressed ? -1 : 0,
                  ),
                  // Inner highlight (top)
                  BoxShadow(
                    color: Colors.white.withOpacity(isDark ? 0.05 : 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(isDark ? 0.03 : 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Search icon with pulse animation
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 1.0 + (math.sin(value * math.pi * 2) * 0.05),
                              child: Icon(
                                Icons.search_rounded,
                                color: colorScheme.primary.withOpacity(0.8),
                                size: 24,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        // Hint text
                        Expanded(
                          child: Text(
                            widget.hintText,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        // Filter button with hover effect
                        if (widget.onFilterTap != null) ...[
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onFilterTap,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
