import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyController extends ChangeNotifier {
  bool _blurOnBackground = true;
  bool _blockScreenshots = false;
  bool _blurActive = false;

  bool get blurOnBackground => _blurOnBackground;
  bool get blockScreenshots => _blockScreenshots;
  bool get blurActive => _blurActive;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _blurOnBackground = prefs.getBool('privacy_blur_on_bg') ?? true;
    _blockScreenshots = prefs.getBool('privacy_block_screenshots') ?? false;
    // aplicar flag si es necesario
    await _applySecureFlag();
    notifyListeners();
  }

  Future<void> setBlurOnBackground(bool v) async {
    _blurOnBackground = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_blur_on_bg', v);
    notifyListeners();
  }

  Future<void> setBlockScreenshots(bool v) async {
    _blockScreenshots = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_block_screenshots', v);
    await _applySecureFlag();
    notifyListeners();
  }

  Future<void> _applySecureFlag() async {
    // Bloqueo de capturas desactivado: requiere integración nativa o plugin compatible.
    // Mantenemos la preferencia para posible activación futura.
  }

  void onAppPaused() {
    if (_blurOnBackground) {
      _blurActive = true;
      notifyListeners();
    }
  }

  void onAppResumed() {
    if (_blurActive) {
      _blurActive = false;
      notifyListeners();
    }
  }
}

class BlurOverlay extends StatelessWidget {
  final PrivacyController controller;
  const BlurOverlay({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    if (!controller.blurActive) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: true,
      child: AnimatedOpacity(
        opacity: controller.blurActive ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          color: Colors.black.withOpacity(0.25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
    );
  }
}
