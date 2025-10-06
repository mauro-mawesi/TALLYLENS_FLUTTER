import 'package:get_it/get_it.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:recibos_flutter/core/services/image_service.dart';
import 'package:recibos_flutter/core/services/receipt_service.dart';
import 'package:recibos_flutter/core/services/search_service.dart';
import 'package:recibos_flutter/core/config/app_config.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:recibos_flutter/core/services/auth_bridge.dart';
import 'package:recibos_flutter/core/services/local_auth_service.dart';
import 'package:recibos_flutter/core/locale/locale_controller.dart';
import 'package:recibos_flutter/features/receipt_detail/bloc/receipt_detail_bloc.dart';
import 'package:recibos_flutter/features/analytics/overview/bloc/analytics_overview_bloc.dart';
import 'package:recibos_flutter/features/analytics/spending/bloc/spending_analytics_bloc.dart';
import 'package:recibos_flutter/features/analytics/product_detail/bloc/product_analytics_bloc.dart';
import 'package:recibos_flutter/core/services/connectivity_service.dart';
import 'package:recibos_flutter/core/services/privacy_controller.dart';
import 'package:recibos_flutter/core/locale/onboarding_controller.dart';
import 'package:recibos_flutter/core/services/widget_service.dart';
import 'package:recibos_flutter/core/services/sync_service.dart';

import 'package:recibos_flutter/features/receipts_list/presentation/bloc/receipts_list_bloc.dart';
import 'package:recibos_flutter/core/services/budget_service.dart';
import 'package:recibos_flutter/core/services/fcm_service.dart';
import 'package:recibos_flutter/features/budgets/list/bloc/budget_list_bloc.dart';
import 'package:recibos_flutter/features/budgets/detail/bloc/budget_detail_bloc.dart';
import 'package:recibos_flutter/features/budgets/form/cubit/budget_form_cubit.dart';
import 'package:recibos_flutter/features/notifications/cubit/notifications_cubit.dart';

final sl = GetIt.instance;

void setupServiceLocator() {
  // --- Blocs ---
  // Se registra como Factory porque la UI creará una nueva instancia por pantalla.
  sl.registerFactory(() => ReceiptsListBloc(receiptService: sl()));
  sl.registerFactory(() => ReceiptDetailBloc(api: sl()));
  sl.registerFactory(() => AnalyticsOverviewBloc(api: sl()));
  sl.registerFactory(() => SpendingAnalyticsBloc(api: sl()));
  sl.registerFactory(() => ProductAnalyticsBloc(api: sl()));

  // Budget Blocs & Cubits
  sl.registerFactory(() => BudgetListBloc(budgetService: sl()));
  sl.registerFactory(() => BudgetDetailBloc(budgetService: sl()));
  sl.registerFactory(() => BudgetFormCubit(budgetService: sl()));
  sl.registerFactory(() => NotificationsCubit(budgetService: sl()));

  // --- Services ---
  // Se registran como LazySingleton para que haya una única instancia en toda la app.
  // No inyectamos ACCESS_TOKEN de dev: el flujo debe ser igual en dev y prod
  sl.registerLazySingleton(() => ApiService());
  sl.registerLazySingleton(() => ImageService());
  sl.registerLazySingleton(() => ConnectivityService()..init());
  sl.registerLazySingleton(() => SyncService(api: sl(), connectivity: sl())..init());
  sl.registerLazySingleton(() => WidgetService(api: sl()));
  sl.registerLazySingleton(() => ReceiptService(apiService: sl(), widgetService: sl(), syncService: sl()));
  sl.registerLazySingleton(() => SearchService(api: sl()));
  sl.registerLazySingleton(() => AuthService(api: sl()));
  sl.registerLazySingleton(() => LocalAuthService());
  sl.registerLazySingleton(() => LocaleController());
  sl.registerLazySingleton(() => PrivacyController());
  sl.registerLazySingleton(() => OnboardingController());

  // Budget & Notification Services
  sl.registerLazySingleton(() => BudgetService(apiService: sl()));
  sl.registerLazySingleton(() => FCMService(budgetService: sl()));
  // Bridge para manejo global de 401 → logout + redirect
  AuthBridge.onUnauthorized = () async {
    // Manejo centralizado de 401 (lock o logout si no hay refresh / loop)
    await sl<AuthService>().handleUnauthorized();
  };
  AuthBridge.onTokensUpdated = (String? access, String? refresh) async {
    await sl<AuthService>().updateTokens(access: access, refresh: refresh);
  };
  // Falla de refresh: usar política tolerante en lugar de logout inmediato
  AuthBridge.onRefreshFailed = () async {
    try {
      await sl<AuthService>().handleUnauthorized();
    } catch (_) {}
  };
}
