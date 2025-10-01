import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final AuthService _authService = sl<AuthService>();
  
  bool _isAuthenticating = false;
  String _authStatus = '';

  @override
  void initState() {
    super.initState();
    // Inicia la autenticación automáticamente una vez que la pantalla está construida.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometricUnlock());
  }

  Future<void> _tryBiometricUnlock() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _authStatus = AppLocalizations.of(context)?.pleaseUseFingerprint ?? '';
    });

    // Usar el AuthService con razón localizada
    final isAuthenticated = await _authService.unlock(
      localizedReason: AppLocalizations.of(context)?.unlockAppReason,
    );

    if (isAuthenticated) {
      // 2. Si la biometría es exitosa, llamar al servicio de negocio para desbloquear.
      if (mounted) {
        context.go('/'); // Navegar a la pantalla principal.
      }
    } else {
      // 3. Si falla, actualizar el estado para que el usuario pueda reintentar.
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _authStatus = AppLocalizations.of(context)!.authFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: FlowColors.backgroundGradient(context),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fingerprint,
                  size: 80,
                  color: FlowColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  t.lockedAppTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _authStatus,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: FlowColors.textSecondary(context),
                      ),
                ),
                const SizedBox(height: 32),
                if (!_isAuthenticating)
                  ElevatedButton.icon(
                    onPressed: _tryBiometricUnlock,
                    icon: const Icon(Icons.refresh),
                    label: Text(t.retry),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
