import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:recibos_flutter/core/locale/locale_controller.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/theme/theme_controller.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:recibos_flutter/core/services/privacy_controller.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/profile_top_hero.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = sl<AuthService>();
    final t = AppLocalizations.of(context)!;
    final user = auth.profile;
    return ThemeSwitchingArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: FlowColors.backgroundGradient(context),
            ),
          ),
          child: AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              final topInset = MediaQuery.of(context).padding.top;
              final bottomInset = MediaQuery.of(context).padding.bottom;
              return ListView(
            padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, bottomInset + 96),
            children: [
              ProfileTopHero(email: user?.email ?? ''),
              const SizedBox(height: 16),
              // User Profile Card
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: FlowColors.glassTint(context),
                child: _ThemeSwitchTile(),
              ),
              const SizedBox(height: 24),
              // Language Section
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  t.languageSection,
                  style: TextStyle(
                    color: FlowColors.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: FlowColors.glassTint(context),
                child: Column(
                  children: [
                    _LangTile(emoji: '🇬🇧', label: t.languageEnglish, code: 'en'),
                    Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.8, color: FlowColors.divider(context)),
                    _LangTile(emoji: '🇪🇸', label: t.languageSpanish, code: 'es'),
                    Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.8, color: FlowColors.divider(context)),
                    _LangTile(emoji: '🇳🇱', label: t.languageDutch, code: 'nl'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Security Section
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  t.security,
                  style: TextStyle(
                    color: FlowColors.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: FlowColors.glassTint(context),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        t.biometricLock,
                        style: TextStyle(color: FlowColors.text(context)),
                      ),
                      value: auth.biometricEnabled,
                      activeColor: FlowColors.primary,
                      onChanged: (v) async {
                        await auth.setBiometricEnabled(v);
                      },
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.8, color: FlowColors.divider(context)),
                    SwitchListTile(
                      title: Text(
                        t.blurOnAppSwitcher,
                        style: TextStyle(color: FlowColors.text(context)),
                      ),
                      subtitle: Text(
                        t.blurOnAppSwitcherSubtitle,
                        style: TextStyle(color: FlowColors.textSecondary(context)),
                      ),
                      value: sl<PrivacyController>().blurOnBackground,
                      activeColor: FlowColors.primary,
                      onChanged: (v) async {
                        await sl<PrivacyController>().setBlurOnBackground(v);
                      },
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.8, color: FlowColors.divider(context)),
                    // Bloquear capturas (Android) desactivado temporalmente por compatibilidad de plugin.
                    SwitchListTile(
                      title: Text(
                        t.lockOnExit,
                        style: TextStyle(color: FlowColors.text(context)),
                      ),
                      value: auth.autoLockEnabled,
                      activeColor: FlowColors.primary,
                      onChanged: (v) async {
                        await auth.setAutoLockEnabled(v);
                      },
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.8, color: FlowColors.divider(context)),
                    ListTile(
                      leading: Icon(Icons.timer_outlined, color: FlowColors.textSecondary(context)),
                      title: Text(
                        t.gracePeriod,
                        style: TextStyle(color: FlowColors.text(context)),
                      ),
                      subtitle: Text(
                        _graceLabel(context, auth.autoLockGrace),
                        style: TextStyle(color: FlowColors.textSecondary(context)),
                      ),
                      onTap: () async {
                        final choice = await showModalBottomSheet<Duration>(
                          context: context,
                          backgroundColor: const Color(0xFF121A2A),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => _GracePicker(current: auth.autoLockGrace),
                        );
                        if (choice != null) await auth.setAutoLockGrace(choice);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: FlowColors.glassTint(context),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.lock_outline, color: FlowColors.textSecondary(context)),
                      title: Text(
                        t.lockNow,
                        style: TextStyle(color: FlowColors.text(context)),
                      ),
                      onTap: () {
                        auth.forceLock();
                        context.go('/unlock');
                      },
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.8, color: FlowColors.divider(context)),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
                      title: Text(
                        t.logout,
                        style: TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                      onTap: () async {
                        await auth.logout();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
            ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _graceLabel(BuildContext context, Duration d) {
    final t = AppLocalizations.of(context)!;
    if (d.inSeconds == 0) return t.graceNone;
    if (d.inSeconds == 15) return t.grace15s;
    if (d.inSeconds == 30) return t.grace30s;
    if (d.inMinutes == 1) return t.grace1m;
    if (d.inMinutes == 5) return t.grace5m;
    return '${d.inSeconds}s';
  }
}

class _GracePicker extends StatelessWidget {
  final Duration current;
  const _GracePicker({required this.current});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final options = <Duration, String>{
      const Duration(seconds: 0): t.graceNone,
      const Duration(seconds: 15): t.grace15s,
      const Duration(seconds: 30): t.grace30s,
      const Duration(minutes: 1): t.grace1m,
      const Duration(minutes: 5): t.grace5m,
    };
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: FlowColors.textSecondary(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ...options.entries.map((e) {
              final selected = e.key == current;
              return ListTile(
                title: Text(
                  e.value,
                  style: TextStyle(
                    color: selected ? FlowColors.primary : FlowColors.text(context),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: FlowColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop<Duration>(e.key),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwitchTile extends StatelessWidget {
  const _ThemeSwitchTile();

  ThemeData _buildLightTheme() {
    final lightTextTheme = GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );
    final lightCS = const ColorScheme.light(
      primary: FlowColors.primary,
      secondary: FlowColors.secondaryLight,
      surface: Color(0xFFFFFFFF),
      background: Color(0xFFF7F8FA),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: lightCS,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      textTheme: lightTextTheme,
    );
  }

  ThemeData _buildDarkTheme() {
    final darkTextTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: FlowColors.textDark,
      displayColor: FlowColors.textDark,
    );
    final darkCS = const ColorScheme.dark(
      primary: FlowColors.primary,
      secondary: FlowColors.secondaryDark,
      surface: Color(0xFF121A2A),
      background: FlowColors.backgroundDark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkCS,
      scaffoldBackgroundColor: FlowColors.backgroundDark,
      textTheme: darkTextTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return ThemeSwitcher.switcher(
      clipper: const ThemeSwitcherCircleClipper(),
      builder: (context, switcher) {
        return SwitchListTile(
          title: Text(
            t.darkMode,
            style: TextStyle(color: FlowColors.text(context)),
          ),
          value: themeController.isDark,
          activeColor: FlowColors.primary,
          onChanged: (v) async {
            final newTheme = v ? _buildDarkTheme() : _buildLightTheme();
            final newMode = v ? ThemeMode.dark : ThemeMode.light;

            // Obtener la posición del switch para centrar la animación
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            final Offset? position = box != null
                ? Offset(box.size.width - 50, box.size.height / 2)
                : null;

            switcher.changeTheme(
              theme: newTheme,
              offset: position,
            );

            await themeController.setMode(newMode);
          },
        );
      },
    );
  }
}

class _LangTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String code;
  const _LangTile({required this.emoji, required this.label, required this.code});

  @override
  Widget build(BuildContext context) {
    final current = sl<LocaleController>().locale?.languageCode;
    final selected = current == code;
    final asset = _flagFor(code);
    return ListTile(
      leading: asset == null
          ? Text(emoji, style: const TextStyle(fontSize: 22))
          : SvgPicture.asset(asset, width: 24, height: 24),
      title: Text(label, style: TextStyle(color: FlowColors.text(context))),
      trailing: selected ? const Icon(Icons.check_circle, color: FlowColors.primary) : null,
      onTap: () {
        sl<LocaleController>().setLocale(Locale(code));
        sl<ApiService>().setLocaleCode(code);
        final auth = sl<AuthService>();
        if (auth.isLoggedIn) {
          // Persistir preferencia en backend de forma silenciosa
          sl<ApiService>().updatePreferredLanguage(code);
        }
      },
    );
  }

  String? _flagFor(String code) {
    switch (code) {
      case 'en':
        return 'assets/flags/gb.svg';
      case 'es':
        return 'assets/flags/es.svg';
      case 'nl':
        return 'assets/flags/nl.svg';
      default:
        return null;
    }
  }
}
