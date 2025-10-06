import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Calcula el radio máximo para cubrir toda la pantalla desde un punto
double calculateMaxRadius(Size size, Offset center) {
  final double maxX = math.max(center.dx, size.width - center.dx);
  final double maxY = math.max(center.dy, size.height - center.dy);
  return math.sqrt(maxX * maxX + maxY * maxY);
}

/// Clipper circular que crece desde un punto
class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset centerAlignment;

  CircularRevealClipper({
    required this.fraction,
    required this.centerAlignment,
  });

  @override
  Path getClip(Size size) {
    final center = centerAlignment;
    final maxRadius = calculateMaxRadius(size, center);
    final radius = fraction * maxRadius;

    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    return path;
  }

  @override
  bool shouldReclip(CircularRevealClipper oldClipper) =>
      oldClipper.fraction != fraction || oldClipper.centerAlignment != centerAlignment;
}
