import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';

/// Un widget que crea un efecto de "vidrio esmerilado" o "glassmorphism".
///
/// Combina un filtro de desenfoque de fondo con un contenedor semi-transparente
/// y un borde sutil para dar la apariencia de estar flotando sobre la UI.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Gradient? borderGradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 24.0,
    this.color,
    this.borderGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blurAmount = isDark ? 15.0 : 10.0;
    final borderOpacity = isDark ? 0.3 : 0.8;
    final shadowColor = isDark ? Colors.black26 : Colors.black12;
    final shadowBlur = isDark ? 12.0 : 8.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurAmount,
          sigmaY: blurAmount,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // El color de fondo del vidrio adapta su opacidad al tema.
            color: color ?? FlowColors.glassTint(context),
            borderRadius: BorderRadius.circular(borderRadius),
            // El borde puede ser un gradiente o un color sólido.
            border: borderGradient != null
                ? null // El gradiente se aplica en el widget `CustomPaint` de abajo.
                : Border.all(color: FlowColors.divider(context), width: 0.8),
            boxShadow: [
              BoxShadow(color: shadowColor, blurRadius: shadowBlur, spreadRadius: 0.5),
            ],
          ),
          // Si hay un gradiente para el borde, lo pintamos aquí.
          child: borderGradient != null
              ? CustomPaint(
                  painter: _GradientBorderPainter(
                    gradient: borderGradient!,
                    borderRadius: borderRadius,
                  ),
                  child: child,
                )
              : child,
        ),
      ),
    );
  }
}

/// Un `CustomPainter` para dibujar un borde con un gradiente.
class _GradientBorderPainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;
  final double borderRadius;

  _GradientBorderPainter({
    required this.gradient,
    this.strokeWidth = 0.8,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
