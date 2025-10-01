import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final t = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return t.emailRequired;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v.trim())) return t.emailInvalid;
    return null;
  }

  String? _validateUsername(String? v) {
    final t = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return t.usernameRequired;
    final usr = v.trim();
    if (usr.length < 3 || usr.length > 30) return t.usernameLength;
    final alnum = RegExp(r'^[a-zA-Z0-9]+$');
    if (!alnum.hasMatch(usr)) return t.usernameAlnum;
    return null;
  }

  String? _validateName(String? v) {
    final t = AppLocalizations.of(context)!;
    if (v != null && v.trim().length > 50) return t.nameMaxLen;
    return null;
  }

  String? _validatePassword(String? v) {
    final t = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return t.passwordRequired;
    if (v.length < 8) return t.passwordMin8;
    final re = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    if (!re.hasMatch(v)) return t.passwordStrength;
    return null;
  }

  String? _validateConfirm(String? v) {
    final t = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return t.confirmRequired;
    if (v != _passwordCtrl.text) return t.confirmMismatch;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
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
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t.registerTitle,
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.registerSubtitle,
                        style: tt.bodyMedium?.copyWith(color: cs.outline),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _firstNameCtrl,
                                        decoration: InputDecoration(labelText: t.firstNameOptional),
                                        validator: _validateName,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastNameCtrl,
                                        decoration: InputDecoration(labelText: t.lastNameOptional),
                                        validator: _validateName,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailCtrl,
                                  decoration: InputDecoration(
                                    labelText: t.emailLabel,
                                    prefixIcon: const Icon(Icons.alternate_email),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _usernameCtrl,
                                  decoration: InputDecoration(
                                    labelText: t.usernameLabel,
                                    prefixIcon: const Icon(Icons.person_outline),
                                  ),
                                  validator: _validateUsername,
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
                                  validator: _validatePassword,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmCtrl,
                                  decoration: InputDecoration(
                                    labelText: t.confirmPasswordLabel,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                  ),
                                  obscureText: true,
                                  validator: _validateConfirm,
                                ),
                                const SizedBox(height: 12),
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
                                      : const Icon(Icons.person_add_alt_1),
                                  label: Text(_loading ? t.creating : t.createAccount),
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
                          Text(t.haveAccount),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(t.signIn),
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
      await sl<AuthService>().register(
        email: _emailCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
      );
      if (!mounted) return;
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.registerSuccess)));
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      setState(() => _error = t.registerFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
