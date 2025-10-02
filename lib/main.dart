import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/router/app_router.dart';
import 'package:recibos_flutter/core/theme/theme_controller.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/locale/locale_controller.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:recibos_flutter/core/services/lock_bridge.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:recibos_flutter/core/services/privacy_controller.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:recibos_flutter/core/locale/onboarding_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  setupServiceLocator();
  await themeController.load();
  // Cargar preferencia de idioma antes de iniciar la app
  await sl<LocaleController>().load();
  // Privacidad
  await sl<PrivacyController>().load();
  await sl<OnboardingController>().load();
  // Propaga el locale al ApiService para enviar X-Locale
  final lc = sl<LocaleController>();
  final api = sl<ApiService>();
  if (lc.locale != null) {
    api.setLocaleCode(lc.locale!.languageCode);
  }
  await sl<AuthService>().init();
  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  late final AuthService _auth;
  DateTime? _backgroundAt;

  @override
  void initState() {
    super.initState();
    _auth = sl<AuthService>();
    _router = createRouter(_auth);
    WidgetsBinding.instance.addObserver(_LifecycleHandlerSmart(
      auth: _auth,
      onBackground: () => _backgroundAt = DateTime.now(),
      shouldLockOnResume: () {
        // Suprime si viene de cámara/galería
        if (LockBridge.suppressNextLock) {
          LockBridge.suppressNextLock = false;
          return false;
        }
        if (!_auth.isLoggedIn || !_auth.biometricEnabled || !_auth.autoLockEnabled) return false;
        if (_backgroundAt == null) return false;
        final elapsed = DateTime.now().difference(_backgroundAt!);
        return elapsed >= _auth.autoLockGrace;
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final darkTextTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: FlowColors.textDark,
      displayColor: FlowColors.textDark,
    );
    final lightTextTheme = GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );

    final privacy = sl<PrivacyController>();
    return AnimatedBuilder(
      animation: Listenable.merge([themeController, sl<LocaleController>(), privacy]),
      builder: (context, _) => MaterialApp.router(
      title: AppLocalizations.of(context)?.appTitle ?? 'Receipts App',
      debugShowCheckedModeBanner: false,
        locale: sl<LocaleController>().locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
          Locale('nl'),
        ],
        builder: (context, child) => Stack(children: [
          if (child != null) child,
          BlurOverlay(controller: privacy),
        ]),
        theme: () {
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
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
              TargetPlatform.linux: ZoomPageTransitionsBuilder(),
              TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
              TargetPlatform.windows: ZoomPageTransitionsBuilder(),
            },
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleTextStyle: lightTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            iconColor: Colors.black54,
            textColor: Colors.black87,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: FlowColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.disabled)) {
                  return lightCS.primary.withOpacity(0.38);
                }
                return lightCS.primary;
              }),
              foregroundColor: MaterialStatePropertyAll(lightCS.onPrimary),
              overlayColor: MaterialStatePropertyAll(lightCS.onPrimary.withOpacity(0.1)),
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(vertical: 14, horizontal: 20)),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: ButtonStyle(
              foregroundColor: MaterialStatePropertyAll(lightCS.primary),
              side: MaterialStatePropertyAll(BorderSide(color: lightCS.outline)),
              overlayColor: MaterialStatePropertyAll(lightCS.primary.withOpacity(0.08)),
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              foregroundColor: MaterialStatePropertyAll(lightCS.primary),
              overlayColor: MaterialStatePropertyAll(lightCS.primary.withOpacity(0.08)),
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.disabled)) {
                  return lightCS.onSurface.withOpacity(0.38);
                }
                return lightCS.onSurface;
              }),
              overlayColor: MaterialStatePropertyAll(lightCS.primary.withOpacity(0.08)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            hintStyle: const TextStyle(color: Color(0xFF9E9EAA)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: FlowColors.primary, width: 1.4),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: lightCS.inverseSurface,
            contentTextStyle: TextStyle(color: lightCS.onInverseSurface),
            actionTextColor: lightCS.inversePrimary,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: CircleBorder(),
          ),
        );
        }(),
        darkTheme: () {
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
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
              TargetPlatform.linux: ZoomPageTransitionsBuilder(),
              TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
              TargetPlatform.windows: ZoomPageTransitionsBuilder(),
            },
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleTextStyle: darkTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            iconTheme: const IconThemeData(color: FlowColors.textDark),
          ),
          cardTheme: CardTheme(
            color: const Color(0xFF121A2A),
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            iconColor: Color(0xFF9E9EAA),
            textColor: FlowColors.textDark,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: FlowColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.disabled)) {
                  return darkCS.primary.withOpacity(0.38);
                }
                return darkCS.primary;
              }),
              foregroundColor: MaterialStatePropertyAll(darkCS.onPrimary),
              overlayColor: MaterialStatePropertyAll(darkCS.onPrimary.withOpacity(0.12)),
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(vertical: 14, horizontal: 20)),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: ButtonStyle(
              foregroundColor: MaterialStatePropertyAll(darkCS.primary),
              side: MaterialStatePropertyAll(BorderSide(color: darkCS.outline)),
              overlayColor: MaterialStatePropertyAll(darkCS.primary.withOpacity(0.10)),
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              foregroundColor: MaterialStatePropertyAll(darkCS.primary),
              overlayColor: MaterialStatePropertyAll(darkCS.primary.withOpacity(0.10)),
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.disabled)) {
                  return darkCS.onSurface.withOpacity(0.38);
                }
                return darkCS.onSurface;
              }),
              overlayColor: MaterialStatePropertyAll(darkCS.primary.withOpacity(0.12)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkCS.surfaceVariant.withOpacity(0.18),
            hintStyle: const TextStyle(color: FlowColors.textSecondaryDark),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: darkCS.outline.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: darkCS.outline.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: FlowColors.primary, width: 1.2),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: darkCS.inverseSurface.withOpacity(0.92),
            contentTextStyle: TextStyle(color: darkCS.onInverseSurface),
            actionTextColor: darkCS.inversePrimary,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: CircleBorder(),
          ),
        );
        }(),
      themeMode: themeController.mode,
      routerConfig: _router,
    ),
    );
  }
}

class _LifecycleHandlerSmart with WidgetsBindingObserver {
  final AuthService auth;
  final VoidCallback onBackground;
  final bool Function() shouldLockOnResume;
  _LifecycleHandlerSmart({required this.auth, required this.onBackground, required this.shouldLockOnResume});
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final privacy = sl<PrivacyController>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      onBackground();
      privacy.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      privacy.onAppResumed();
      if (shouldLockOnResume()) {
        auth.forceLock();
      }
    }
  }
}
