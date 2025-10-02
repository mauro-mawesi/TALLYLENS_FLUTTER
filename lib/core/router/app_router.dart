import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/features/add_receipt/presentation/screens/add_receipt_screen.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/screens/receipts_list_screen.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/screens/edit_receipt_screen.dart';
import 'package:recibos_flutter/features/analytics/overview/analytics_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/screens/receipt_detail_screen.dart';
import 'package:recibos_flutter/features/auth/login_screen.dart';
import 'package:recibos_flutter/features/auth/register_screen.dart';
import 'package:recibos_flutter/features/auth/unlock_screen.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/screens/receipt_image_screen.dart';
import 'package:recibos_flutter/features/processing/processing_screen.dart';
import 'package:recibos_flutter/features/navigation/app_shell.dart';
import 'package:recibos_flutter/features/profile/profile_screen.dart';
import 'package:recibos_flutter/features/analytics/spending/spending_analysis_screen.dart';
import 'package:recibos_flutter/features/analytics/product_detail/product_detail_screen.dart';
import 'package:recibos_flutter/core/locale/onboarding_controller.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/features/onboarding/onboarding_screen.dart';

GoRouter createRouter(AuthService auth) {
  final onboarding = sl<OnboardingController>();
  return GoRouter(
  initialLocation: !onboarding.isDone
      ? '/onboarding'
      : (auth.isLoggedIn
          ? (auth.biometricEnabled && auth.locked ? '/unlock' : '/')
          : '/login'),
  refreshListenable: auth,
  redirect: (context, state) {
    final obDone = onboarding.isDone;
    final loggedIn = auth.isLoggedIn;
    final loggingIn = state.matchedLocation == '/login';
    final registering = state.matchedLocation == '/register';
    final unlocking = state.matchedLocation == '/unlock';
    final onboardingPath = state.matchedLocation == '/onboarding';

    // 1) Onboarding: si no está completo, permitimos quedarse en onboarding y no redirigir a nada más
    if (!obDone) {
      if (!onboardingPath) return '/onboarding';
      return null; // permanecer en onboarding sin considerar otras reglas
    }

    // 2) Autenticación
    if (!loggedIn && !(loggingIn || registering)) return '/login';
    if (loggedIn) {
      if (auth.biometricEnabled && auth.locked && !unlocking) return '/unlock';
      if (!auth.locked && (loggingIn || registering)) return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/unlock',
      name: 'unlock',
      builder: (context, state) => const UnlockScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'receipts_list',
          builder: (context, state) => ReceiptsListScreen(initialFilters: state.extra as Map<String, dynamic>?),
        ),
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const AnalyticsOverviewScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const _NotificationsScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/analytics/spending',
      name: 'spending_analysis',
      builder: (context, state) => const SpendingAnalysisScreen(),
    ),
    GoRoute(
      path: '/analytics/product',
      name: 'product_detail',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final id = (extra?['productId'] ?? extra?['id'] ?? '').toString();
        final name = extra?['name']?.toString();
        return ProductDetailScreen(productId: id, productName: name);
      },
    ),
    GoRoute(
      path: '/add',
      name: 'add_receipt',
      builder: (context, state) => const AddReceiptScreen(),
    ),
    GoRoute(
      path: '/processing',
      name: 'processing',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final id = extra?['id']?.toString();
        final imageUrl = extra?['imageUrl']?.toString();
        final uploadPath = extra?['uploadPath']?.toString();
        return ProcessingScreen(receiptId: id, imageUrl: imageUrl, uploadPath: uploadPath);
      },
    ),
    GoRoute(
      path: '/detalle',
      name: 'receipt_detail',
      builder: (context, state) => ReceiptDetailScreen(receipt: state.extra),
    ),
    GoRoute(
      path: '/receipt-image',
      name: 'receipt_image',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final id = extra?['id']?.toString() ?? '';
        return ReceiptImageScreen(receiptId: id);
      },
    ),
    GoRoute(
      path: '/edit',
      name: 'edit_receipt',
      builder: (context, state) => EditReceiptScreen(receipt: state.extra),
    ),
  ],
);
}

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: const Center(child: Text('Próximamente: alertas y notificaciones')), 
    );
  }
}
