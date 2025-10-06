import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:recibos_flutter/core/theme/theme_controller.dart';
import 'package:recibos_flutter/core/theme/circular_reveal_clipper.dart';

/// Overlay que muestra la animación circular durante el cambio de tema
class ThemeTransitionOverlay extends StatefulWidget {
  final ThemeController controller;
  final GlobalKey appKey;

  const ThemeTransitionOverlay({
    super.key,
    required this.controller,
    required this.appKey,
  });

  @override
  State<ThemeTransitionOverlay> createState() => _ThemeTransitionOverlayState();
}

class _ThemeTransitionOverlayState extends State<ThemeTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  ui.Image? _snapshot;
  bool _isCapturing = false;
  bool _hasStartedAnimation = false;

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
    _snapshot?.dispose();
    super.dispose();
  }

  Future<void> _onThemeChange() async {
    // Solo capturar UNA VEZ al inicio de la animación
    if (widget.controller.isAnimating &&
        !widget.controller.readyToChange &&
        !_isCapturing &&
        !_hasStartedAnimation &&
        _snapshot == null) {
      _isCapturing = true;
      _hasStartedAnimation = true;

      // Capturar snapshot del tema actual INMEDIATAMENTE
      await _captureSnapshot();

      // Notificar al controller que el snapshot está listo
      widget.controller.notifySnapshotReady();

      _isCapturing = false;

      if (mounted && _snapshot != null) {
        // Iniciar animación después de capturar
        _animationController.forward(from: 0.0).then((_) {
          // Limpiar snapshot después de la animación
          if (mounted) {
            setState(() {
              _snapshot?.dispose();
              _snapshot = null;
              _hasStartedAnimation = false;
            });
          }
        });
      }
    } else if (!widget.controller.isAnimating) {
      // Reset cuando termina la animación
      _hasStartedAnimation = false;
    }
  }

  Future<void> _captureSnapshot() async {
    try {
      final RenderRepaintBoundary? boundary = widget.appKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        if (mounted) {
          setState(() {
            _snapshot?.dispose();
            _snapshot = image;
          });
        }
      }
    } catch (e) {
      // Si falla la captura, continuar sin snapshot
      debugPrint('Failed to capture snapshot: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _animation]),
      builder: (context, child) {
        if (!widget.controller.isAnimating || _snapshot == null) {
          return const SizedBox.shrink();
        }

        final screenSize = MediaQuery.of(context).size;
        final center = widget.controller.tapPosition ??
            Offset(screenSize.width / 2, screenSize.height / 2);
        final maxRadius = calculateMaxRadius(screenSize, center);

        // Círculo que CRECE desde el switch revelando el NUEVO tema
        // Fuera del círculo: Tema ANTIGUO (snapshot)
        // Dentro del círculo: Tema NUEVO (la app real debajo)
        return Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                // Snapshot del tema antiguo cubriendo todo
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SnapshotPainter(image: _snapshot!),
                  ),
                ),
                // Agujero circular que crece revelando el nuevo tema
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CircularHolePainter(
                      center: center,
                      radius: maxRadius * _animation.value, // Crece desde el switch
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Painter que dibuja el snapshot capturado
class _SnapshotPainter extends CustomPainter {
  final ui.Image image;

  _SnapshotPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(_SnapshotPainter oldDelegate) => oldDelegate.image != image;
}

/// Painter que crea un agujero circular (revela el nuevo tema)
class _CircularHolePainter extends CustomPainter {
  final Offset center;
  final double radius;

  _CircularHolePainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..blendMode = BlendMode.dstOut;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.black);
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CircularHolePainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}
