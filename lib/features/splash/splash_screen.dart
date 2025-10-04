import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Splash screen con animación personalizada para TallyLens
/// Usa los colores del logo: naranja, rosa, morado, azul
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _shimmerController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Fade in animation (0 → 1)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Scale animation (0.3 → 1.0 con bounce)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Rotate animation (0 → 360°)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rotateAnimation = CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeOutCubic,
    );

    // Shimmer effect (brillo que recorre)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Secuencia de animaciones
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Iniciar todas las animaciones en paralelo
    _fadeController.forward();
    _scaleController.forward();
    _rotateController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _shimmerController.forward();

    // Las animaciones terminan y el main.dart se encarga de ocultar el splash
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628), // Fondo oscuro de tu app
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _fadeAnimation,
            _scaleAnimation,
            _rotateAnimation,
            _shimmerController,
          ]),
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: 0.3 + (_scaleAnimation.value * 0.7), // 0.3 → 1.0
                child: Transform.rotate(
                  angle: _rotateAnimation.value * math.pi * 2, // 0 → 360°
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow effect detrás del logo
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.3 * _fadeAnimation.value),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                            BoxShadow(
                              color: const Color(0xFF8338EC).withOpacity(0.2 * _fadeAnimation.value),
                              blurRadius: 80,
                              spreadRadius: 30,
                            ),
                          ],
                        ),
                      ),

                      // Logo principal
                      Image.asset(
                        'assets/brand/tallylens_icon_512.png',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),

                      // Shimmer overlay (brillo que recorre)
                      if (_shimmerController.value > 0)
                        Positioned.fill(
                          child: ClipOval(
                            child: CustomPaint(
                              painter: _ShimmerPainter(
                                progress: _shimmerController.value,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Painter para el efecto shimmer (brillo que recorre el logo)
class _ShimmerPainter extends CustomPainter {
  final double progress;

  _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Posición del brillo (de izquierda a derecha)
    final shimmerX = -radius + (progress * radius * 2);

    final gradient = RadialGradient(
      center: Alignment(shimmerX / radius, 0),
      radius: 0.6,
      colors: [
        Colors.white.withOpacity(0.4),
        Colors.white.withOpacity(0.2),
        Colors.white.withOpacity(0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
