import 'package:flutter/material.dart';

/// Flow-Connect color palette with dynamic theme support
class FlowColors {
  // Primary colors (same in both themes)
  static const Color primary = Color(0xFF8A2BE2); // Purple
  static const Color accentCyan = Color(0xFF00E3FF); // Cyan for gradients

  // Dark theme constants
  static const Color backgroundDark = Color(0xFF0A0A1F);
  static const Color secondaryDark = Color(0xFF00FF7F); // Neon Green
  static const Color textDark = Color(0xFFEBEBF5);
  static const Color textSecondaryDark = Color(0xFF9E9EAA);

  // Light theme constants
  static const Color backgroundLight = Color(0xFFF7F8FA);
  static const Color secondaryLight = Color(0xFF00C853); // Darker green for contrast
  static const Color textLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Theme-specific colors
  static Color background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0A0A1F) : const Color(0xFFF7F8FA);
  }

  static List<Color> backgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
      ? [const Color(0xFF0A0A1F), const Color(0xFF0B0B22)]
      : [const Color(0xFFF7F8FA), const Color(0xFFE8E9EC)];
  }

  static Color secondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF00FF7F) : const Color(0xFF00C853);
  }

  static Color text(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFEBEBF5) : const Color(0xFF1A1A2E);
  }

  static Color textSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF9E9EAA) : const Color(0xFF64748B);
  }

  static Color glassTint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Colors.white.withOpacity(isDark ? 0.15 : 0.08);
  }

  static Color iconColor(BuildContext context) {
    return text(context);
  }

  static Color divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Colors.white.withOpacity(isDark ? 0.1 : 0.15);
  }
}