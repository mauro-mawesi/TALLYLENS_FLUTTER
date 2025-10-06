import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Clipper que crea una forma circular que se expande desde un punto
class CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  CircularRevealClipper({
    required this.center,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(CircularRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}

/// Calcula el radio máximo necesario para cubrir toda la pantalla desde un punto
double calculateMaxRadius(Size screenSize, Offset center) {
  final distances = [
    center.distance, // Top-left
    Offset(screenSize.width - center.dx, center.dy).distance, // Top-right
    Offset(center.dx, screenSize.height - center.dy).distance, // Bottom-left
    Offset(screenSize.width - center.dx, screenSize.height - center.dy).distance, // Bottom-right
  ];
  return distances.reduce(math.max);
}
