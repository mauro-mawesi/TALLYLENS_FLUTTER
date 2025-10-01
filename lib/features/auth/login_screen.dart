import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _bioSupported = false;
  bool _bioEnabled = false;

  @override
  void dispose() {
    _identityCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _setupBiometricState();
  }

  Future<void> _setupBiometricState() async {
    final localAuth = LocalAuthentication();
    final supported = await localAuth.isDeviceSupported();
    final auth = sl<AuthService>();
    setState(() {
      _bioSupported = supported;
      _bioEnabled = auth.biometricEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = AppLocalizations.of(context)!;

    final auth = sl<AuthService>();
    final loggedIn = auth.isLoggedIn;
    return Scaffold(
      body: Stack(
        children: [
          // Fondo sutil con gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.surface, cs.surfaceVariant.withOpacity(0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Branding (icon + title)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App icon asset (foreground, no background)
                          Image.asset(
                            'assets/brand/tallylens_icon_512.png',
                            width: 40,
                            height: 40,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            t.appTitle,
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.brandingSubtitle,
                        style: tt.bodyMedium?.copyWith(color: cs.outline),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Acceso biométrico rápido si ya hay sesión almacenada
                      if (loggedIn && _bioSupported && auth.biometricEnabled) ...[
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(t.savedSessionTitle, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text(t.savedSessionSubtitle, style: tt.bodyMedium?.copyWith(color: cs.outline)),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () async {
                                    final ok = await auth.unlock(localizedReason: t.unlockAppReason);
                                    if (!mounted) return;
                                    if (ok) {
                                      context.go('/');
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.authFailed)));
                                    }
                                  },
                                  icon: const Icon(Icons.fingerprint),
                                  label: Text(t.useBiometrics),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/unlock'),
                                  child: Text(t.openUnlockScreen),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tarjeta de login
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(t.loginTitle, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _identityCtrl,
                                  decoration: InputDecoration(
                                    labelText: t.identityLabel,
                                    prefixIcon: const Icon(Icons.person_outline),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? t.identityRequired : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  decoration: InputDecoration(
                                    labelText: t.passwordLabel,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                    ),
                                  ),
                                  obscureText: _obscure,
                                  validator: (v) => (v == null || v.length < 8) ? t.min8Chars : null,
                                ),
                                const SizedBox(height: 12),
                                if (_bioSupported) SwitchListTile(
                                  value: _bioEnabled,
                                  onChanged: (v) async {
                                    setState(() => _bioEnabled = v);
                                    await auth.setBiometricEnabled(v);
                                  },
                                  title: Text(t.useBiometricLock),
                                  subtitle: Text(t.biometricLockSubtitle),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.recoveryNotImplemented))),
                                    child: Text(t.forgotPassword),
                                  ),
                                ),

                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: _error == null
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Text(_error!, style: TextStyle(color: cs.error)),
                                        ),
                                ),

                                FilledButton.icon(
                                  onPressed: _loading ? null : _onSubmit,
                                  icon: _loading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.login),
                                  label: Text(_loading ? t.loggingIn : t.loginButton),
                                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.noAccount),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: Text(t.createAccount),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = AppLocalizations.of(context)!;
      final identity = _identityCtrl.text.trim();
      final password = _passwordCtrl.text;
      final isEmail = identity.contains('@');
      await sl<AuthService>().login(email: isEmail ? identity : null, username: isEmail ? null : identity, password: password);
      // Respeta preferencia de biometría elegida en el switch
      if (_bioSupported) {
        await sl<AuthService>().setBiometricEnabled(_bioEnabled);
      }
      if (!mounted) return;
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.welcome)));
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      setState(() => _error = t.invalidCredentials);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
