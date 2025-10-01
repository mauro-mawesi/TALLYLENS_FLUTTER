import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SmartCaptureScreen extends StatefulWidget {
  const SmartCaptureScreen({super.key});

  @override
  State<SmartCaptureScreen> createState() => _SmartCaptureScreenState();
}

class _SmartCaptureScreenState extends State<SmartCaptureScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initFuture;
  late final AnimationController _overlayController;
  Timer? _autoTimer;
  bool _isCapturing = false;
  bool _autoEnabled = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _overlayController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _initFuture = _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    _overlayController.dispose();
    _controller?.dispose();
    _controller = null;
    _isDisposed = true;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initFuture = _initCamera();
      if (mounted) setState(() {});
    }
  }

  Future<void> _initCamera() async {
    if (_isDisposed) return;
    // Cerrar instancia previa por seguridad
    try { await _controller?.dispose(); } catch (_) {}
    _controller = null;
    final cameras = await availableCameras();
    final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
    final ctrl = CameraController(back, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    _controller = ctrl;
    await ctrl.initialize();
    _scheduleAutoTimer();
  }

  void _scheduleAutoTimer() {
    _autoTimer?.cancel();
    if (!_autoEnabled) return;
    _autoTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted || !_autoEnabled) return;
      await _capture();
    });
  }

  Future<void> _capture() async {
    if (_controller == null || _isCapturing) return;
    try {
      HapticFeedback.heavyImpact();
      setState(() => _isCapturing = true);
      _autoTimer?.cancel();
      if (!mounted || _controller == null) return;
      if (!(_controller!.value.isInitialized) || _controller!.value.isTakingPicture) return;
      final file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop<File>(File(file.path));
    } catch (_) {
      setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(t.newReceiptTitle),
      ),
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!(_controller?.value.isInitialized ?? false)) {
            return Center(child: Text(t.errorGeneric));
          }
          return Stack(
            children: [
              Positioned.fill(child: CameraPreview(_controller!)),
              // Overlay de detección simulado (neón)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _overlayController,
                    builder: (context, _) {
                      final v = _overlayController.value; // 0..1
                      final glow = 6 + 10 * v;
                      return CustomPaint(
                        painter: _NeonRectPainter(glow: glow),
                      );
                    },
                  ),
                ),
              ),
              // Controles
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() => _autoEnabled = !_autoEnabled);
                            if (_autoEnabled) {
                              _scheduleAutoTimer();
                            } else {
                              _autoTimer?.cancel();
                            }
                          },
                          icon: Icon(_autoEnabled ? Icons.auto_awesome : Icons.auto_awesome_outlined, color: Colors.white),
                          tooltip: 'Auto',
                        ),
                        GestureDetector(
                          onTap: _capture,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.25), blurRadius: 12)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NeonRectPainter extends CustomPainter {
  final double glow;
  _NeonRectPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(w * 0.08, h * 0.16, w * 0.84, h * 0.56);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final glowPaint = Paint()
      ..color = const Color(0xFF00FF7F).withOpacity(0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, glow);
    canvas.drawRRect(rrect, glowPaint);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF00FF7F);
    canvas.drawRRect(rrect, stroke);
  }

  @override
  bool shouldRepaint(covariant _NeonRectPainter oldDelegate) => oldDelegate.glow != glow;
}
