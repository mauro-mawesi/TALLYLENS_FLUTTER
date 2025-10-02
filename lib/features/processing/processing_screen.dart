import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/services/receipt_service.dart';
import 'dart:io';
import 'package:recibos_flutter/core/services/errors.dart';

class ProcessingScreen extends StatefulWidget {
  final String? receiptId;
  final String? imageUrl;
  // Si viene uploadPath, esta pantalla se encarga de subir y crear el recibo
  final String? uploadPath;
  const ProcessingScreen({super.key, this.receiptId, this.imageUrl, this.uploadPath});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final ApiService _api;
  late final ReceiptService _receiptService;
  Timer? _timer;
  Timer? _msgTimer;
  late final AnimationController _controller;

  String _statusText = '';
  int _step = 0;
  String? _receiptId;
  String? _localImagePath;
  bool _processedByMLKit = false;
  String? _source; // 'camera' | 'gallery'
  bool _hasError = false;
  String? _errorMessage;
  DateTime? _pollStartedAt;
  bool _didBoot = false;

  @override
  void initState() {
    super.initState();
    _api = sl<ApiService>();
    _receiptService = sl<ReceiptService>();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _receiptId = widget.receiptId;
    _localImagePath = widget.uploadPath;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didBoot) {
      _didBoot = true;
      // Lee flags pasados por navegación (si existen)
      try {
        final extra = GoRouterState.of(context).extra;
        if (extra is Map) {
          _processedByMLKit = (extra['processedByMLKit'] as bool?) ?? false;
          final s = extra['source'];
          if (s is String) _source = s;
        }
      } catch (_) {}
      // Inicializa mensajes localizados ahora que hay dependencias
      final t = AppLocalizations.of(context);
      setState(() => _statusText = t?.processingAnalyzing ?? 'Analyzing your receipt...');
      _msgTimer = Timer.periodic(const Duration(seconds: 3), (tm) {
        if (!mounted) return tm.cancel();
        setState(() {
          _step = (_step + 1) % 4;
          final tt = AppLocalizations.of(context);
          switch (_step) {
            case 0:
              _statusText = tt?.processingAnalyzing ?? 'Analyzing your receipt...';
              break;
            case 1:
              _statusText = tt?.processingOCR ?? 'Extracting text (OCR)...';
              break;
            case 2:
              _statusText = tt?.processingProducts ?? 'Identifying products...';
              break;
            case 3:
              _statusText = tt?.processingCategorizing ?? 'Categorizing and computing totals...';
              break;
          }
        });
      });
      // Lanzamos boot cuando ya existen dependencias (Localizations, Theme, etc.)
      WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
    }
  }

  Future<void> _boot() async {
    // Si hay uploadPath, hacemos upload + create primero
    if (widget.uploadPath != null && widget.uploadPath!.isNotEmpty) {
      final t = AppLocalizations.of(context);
      setState(() => _statusText = t?.processingUploading ?? 'Uploading image...');
      try {
        final file = File(widget.uploadPath!);
        final created = await _receiptService.createNewReceipt(
          file,
          processedByMLKit: _processedByMLKit,
          source: _source,
        );
        final data = created is Map<String, dynamic>
            ? (created['data'] as Map<String, dynamic>? ?? created)
            : <String, dynamic>{};
        final id = (data['id'] ?? '').toString();
        if (id.isNotEmpty) {
          // empezamos a hacer polling
          setState(() {
            _receiptId = id;
            final t2 = AppLocalizations.of(context);
            _statusText = t2?.processingAnalyzing ?? 'Analyzing your receipt...';
          });
          _startPolling();
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() { _hasError = true; _errorMessage = e.toString(); });
        }
        return;
      }
    } else {
      _startPolling();
    }
  }

  void _startPolling() {
    _hasError = false;
    _errorMessage = null;
    _pollStartedAt = DateTime.now();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final id = _receiptId;
      if (id == null || id.isEmpty) return;
      final data = await _api.getReceiptById(id);
      final status = (data['processingStatus'] ?? data['processing_status'] ?? '').toString();
      if (status == 'completed') {
        _finish(data);
      }
      if (_pollStartedAt != null && DateTime.now().difference(_pollStartedAt!).inSeconds > 120) {
        // Mantén mensaje de analizando si tarda
        if (mounted) {
          final t = AppLocalizations.of(context);
          setState(() { _statusText = t?.processingAnalyzing ?? 'Analyzing your receipt...'; });
        }
      }
    } catch (e) {
      if (e is UnauthorizedException) {
        _timer?.cancel();
        return;
      }
      if (mounted) {
        setState(() { _hasError = true; _errorMessage = e.toString(); });
      }
    }
  }

  void _finish(Map<String, dynamic> receipt) {
    _timer?.cancel();
    if (!mounted) return;
    // Reemplaza la pantalla de procesamiento por el detalle, preservando la lista detrás
    context.pushReplacement('/detalle', extra: receipt);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.processingTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_localImagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(File(_localImagePath!), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (widget.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(widget.imageUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      return CustomPaint(
                        painter: _RadarPainter(_controller.value, cs.primary, cs.secondary),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _hasError ? (_errorMessage ?? AppLocalizations.of(context)!.errorGeneric) : _statusText,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              if (_hasError)
                Center(
                  child: Text(
                    t.retryOrGoHome,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_hasError || _receiptId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (_receiptId != null) {
                            context.pushReplacement('/detalle', extra: {'id': _receiptId});
                          } else {
                            _hasError = false; _errorMessage = null; _boot();
                          }
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(t.continueLabel),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(t.goHome),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t; // 0..1
  final Color a;
  final Color b;
  _RadarPainter(this.t, this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final progress = (t + i / 3) % 1.0;
      final radius = progress * maxR;
      final color = Color.lerp(a, b, progress)!.withOpacity(1 - progress);
      paint
        ..color = color
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }

    // punto central
    final dotPaint = Paint()..color = a;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.t != t;
}
