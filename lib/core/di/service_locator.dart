import 'package:get_it/get_it.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:recibos_flutter/core/services/image_service.dart';
import 'package:recibos_flutter/core/services/receipt_service.dart';
import 'package:recibos_flutter/core/config/app_config.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:recibos_flutter/core/services/auth_bridge.dart';
import 'package:recibos_flutter/core/services/local_auth_service.dart';
import 'package:recibos_flutter/core/locale/locale_controller.dart';
import 'package:recibos_flutter/features/receipt_detail/bloc/receipt_detail_bloc.dart';
import 'package:recibos_flutter/features/analytics/overview/bloc/analytics_overview_bloc.dart';
import 'package:recibos_flutter/features/analytics/spending/bloc/spending_analytics_bloc.dart';
import 'package:recibos_flutter/features/analytics/product_detail/bloc/product_analytics_bloc.dart';

import 'package:recibos_flutter/features/receipts_list/presentation/bloc/receipts_list_bloc.dart';

final sl = GetIt.instance;

void setupServiceLocator() {
  // --- Blocs ---
  // Se registra como Factory porque la UI creará una nueva instancia por pantalla.
  sl.registerFactory(() => ReceiptsListBloc(receiptService: sl()));
  sl.registerFactory(() => ReceiptDetailBloc(api: sl()));
  sl.registerFactory(() => AnalyticsOverviewBloc(api: sl()));
  sl.registerFactory(() => SpendingAnalyticsBloc(api: sl()));
  sl.registerFactory(() => ProductAnalyticsBloc(api: sl()));

  // --- Services ---
  // Se registran como LazySingleton para que haya una única instancia en toda la app.
  sl.registerLazySingleton(() => ApiService()..setAccessToken(kDevAccessToken));
  sl.registerLazySingleton(() => ImageService());
  sl.registerLazySingleton(() => ReceiptService(apiService: sl()));
  sl.registerLazySingleton(() => AuthService(api: sl()));
  sl.registerLazySingleton(() => LocalAuthService());
  sl.registerLazySingleton(() => LocaleController());
  // Bridge para manejo global de 401 → logout + redirect
  AuthBridge.onUnauthorized = () async {
    await sl<AuthService>().logout();
  };
  AuthBridge.onTokensUpdated = (String? access, String? refresh) async {
    await sl<AuthService>().updateTokens(access: access, refresh: refresh);
  };
}
