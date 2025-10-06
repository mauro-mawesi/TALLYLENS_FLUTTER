import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/theme/theme_controller.dart';

/// Wrapper que maneja la transición entre temas
class ThemeSwitcherWrapper extends StatelessWidget {
  final ThemeController controller;
  final Widget Function(BuildContext context, ThemeMode themeMode) builder;

  const ThemeSwitcherWrapper({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return builder(context, controller.mode);
      },
    );
  }
}
