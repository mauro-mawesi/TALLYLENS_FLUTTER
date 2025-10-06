import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/image_service.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart' as ml;
import 'package:recibos_flutter/core/theme/app_colors.dart';

class AddReceiptScreen extends StatefulWidget {
  const AddReceiptScreen({super.key});

  @override
  State<AddReceiptScreen> createState() => _AddReceiptScreenState();
}

class _AddReceiptScreenState extends State<AddReceiptScreen> {
  final ImageService _imageService = sl<ImageService>();

  File? _selectedImage;
  bool _isLoading = false;
  int _quarterTurns = 0;
  bool _fitHeight = false;
  bool _processedByMLKit = false;
  String? _source; // 'camera' | 'gallery'

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading) return;

    try {
      final image = source == ImageSource.gallery
          ? await _imageService.pickFromGallery()
          : await _imageService.pickFromCamera();

      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
          _processedByMLKit = false;
          _source = source == ImageSource.gallery ? 'gallery' : 'camera';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleScanTap() async {
    if (_isLoading) return;
    HapticFeedback.mediumImpact();
    // Usar ML Kit document scanner
    File? file = await _scanWithMlKit();
    if (file != null && mounted) {
      setState(() {
        _selectedImage = file;
        _processedByMLKit = true;
        _source = 'camera';
      });
    } else if (mounted) {
      // Mostrar mensaje si falla o se cancela
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.scanCancelled),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<File?> _scanWithMlKit() async {
    try {
      // Compatible con 0.4.0: requiere options con al menos el modo
      final scanner = ml.DocumentScanner(
        options: ml.DocumentScannerOptions(
          mode: ml.ScannerMode.full,
        ),
      );
      final res = await scanner.scanDocument();
      if (res == null) return null;
      // Intentar extraer path del primer resultado de manera resiliente
      String? path;
      try {
        final images = (res as dynamic).images as List?; // algunos plugins exponen .images
        if (images != null && images.isNotEmpty) {
          final first = images.first;
          if (first is String) path = first;
          // algunos retornan objetos con .path
          else if ((first as dynamic).path != null) path = first.path as String;
        }
      } catch (_) {}
      if (path == null) {
        try {
          final pages = (res as dynamic).pages as List?; // otros exponen .pages
          if (pages != null && pages.isNotEmpty) {
            final first = pages.first;
            if ((first as dynamic).imagePath != null) path = first.imagePath as String;
          }
        } catch (_) {}
      }
      if (path == null) return null;
      return File(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadAndCreateReceipt() async {
    if (_selectedImage == null || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Navegar inmediatamente a procesamiento; allí se hará upload + create + polling
      final path = _selectedImage!.path;
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.push('/processing', extra: {
        'uploadPath': path,
        'processedByMLKit': _processedByMLKit,
        'source': _source,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorPrefix(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: FlowColors.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          t.newReceiptTitle,
          style: TextStyle(color: FlowColors.text(context), fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          // Fondo gradiente
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: FlowColors.backgroundGradient(context),
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Contenido principal en columna: Preview + Dock (sin solaparse)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                children: [
                  // Preview expandible
                  Expanded(
                    child: Builder(builder: (context) {
                      final media = MediaQuery.of(context);
                      final screenH = media.size.height;
                      final safeTop = media.padding.top;
                      final previewH = (screenH - safeTop - 240).clamp(280.0, screenH * 0.8);
                      return Center(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: FlowColors.primary.withOpacity(0.22),
                                blurRadius: 18,
                                spreadRadius: 0.5,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: GlassCard(
                            borderRadius: 24,
                            padding: const EdgeInsets.all(16),
                            color: FlowColors.glassTint(context).withOpacity(0.4),
                            child: SizedBox(
                              height: previewH,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  color: Colors.transparent,
                                  child: _selectedImage != null
                                      ? Stack(
                                          children: [
                                            Positioned.fill(
                                              child: InteractiveViewer(
                                                minScale: 0.8,
                                                maxScale: 4,
                                                child: RotatedBox(
                                                  quarterTurns: _quarterTurns,
                                                  child: Image.file(
                                                    _selectedImage!,
                                                    fit: _fitHeight ? BoxFit.fitHeight : BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Row(
                                                children: [
                                                  _SmallGlassIconButton(
                                                    icon: Icons.rotate_right,
                                                    onTap: () {
                                                      HapticFeedback.selectionClick();
                                                      setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _SmallGlassIconButton(
                                                    icon: _fitHeight ? Icons.height : Icons.fit_screen,
                                                    onTap: () {
                                                      HapticFeedback.selectionClick();
                                                      setState(() => _fitHeight = !_fitHeight);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : _placeholder(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  // Dock inferior (no se superpone al preview)
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    color: FlowColors.glassTint(context).withOpacity(0.2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedImage == null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _NeonCircleButton(
                                icon: Icons.document_scanner_rounded,
                                label: t.scan,
                                onTap: _handleScanTap,
                              ),
                              _CircleOutlineButton(
                                icon: Icons.image_outlined,
                                label: t.gallery,
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  await _pickImage(ImageSource.gallery);
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _selectedImage = null);
                            },
                            icon: const Icon(Icons.refresh, size: 20),
                            label: Text(t.changeImage),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _NeonCTAButton(
                            loading: _isLoading,
                            enabled: _selectedImage != null && !_isLoading,
                            label: _isLoading ? t.uploading : t.confirmAndUpload,
                            onPressed: _selectedImage == null || _isLoading ? null : () async {
                              HapticFeedback.lightImpact();
                              await _uploadAndCreateReceipt();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.newReceiptTitle,
            style: TextStyle(color: cs.onSurfaceVariant),
          )
        ],
      ),
    );
  }

}

class _NeonCircleButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NeonCircleButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_NeonCircleButton> createState() => _NeonCircleButtonState();
}

class _NeonCircleButtonState extends State<_NeonCircleButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(from: 0),
      onTapCancel: () => _c.reverse(),
      onTapUp: (_) => _c.reverse(),
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic).value;
              final scale = 1 - (0.04 * t);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [FlowColors.primary, FlowColors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: FlowColors.primary.withOpacity(0.45), blurRadius: 22, spreadRadius: 3),
                      ],
                    ),
                    child: Center(child: Icon(widget.icon, color: Colors.white, size: 28)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) => Text(
              widget.label,
              style: TextStyle(
                color: FlowColors.text(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonCTAButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final String label;
  final VoidCallback? onPressed;
  const _NeonCTAButton({required this.loading, required this.enabled, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [FlowColors.primary, FlowColors.accentCyan]),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(color: FlowColors.primary.withOpacity(0.45), blurRadius: 22, spreadRadius: 3),
              ],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CircleOutlineButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: FlowColors.primary.withOpacity(0.6), width: 2),
            ),
            child: Icon(icon, color: FlowColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: FlowColors.text(context),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallGlassIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FlowColors.glassTint(context).withOpacity(0.3),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.grey).withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: FlowColors.text(context), size: 18),
      ),
    );
  }
}
