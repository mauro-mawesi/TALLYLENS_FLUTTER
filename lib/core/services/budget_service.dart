import 'api_service.dart';
import 'package:recibos_flutter/core/models/budget.dart';
import 'package:recibos_flutter/core/models/budget_alert.dart';
import 'package:recibos_flutter/core/models/notification_preference.dart';

/// Servicio que maneja la lógica de negocio relacionada con presupuestos.
/// Orquesta las operaciones utilizando ApiService y provee métodos de alto nivel.
class BudgetService {
  final ApiService _apiService;

  BudgetService({
    required ApiService apiService,
  }) : _apiService = apiService;

  // ============================================================================
  // BUDGETS - CRUD Operations
  // ============================================================================

  /// Obtiene la lista de presupuestos del usuario.
  /// Soporta filtrado por categoría, período y estado.
  Future<List<Budget>> getBudgets({
    String? category,
    String? period,
    bool? isActive,
  }) async {
    final budgets = await _apiService.getBudgets(
      category: category,
      period: period,
      isActive: isActive,
    );

    return budgets.map((json) => Budget.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Obtiene un presupuesto específico por ID.
  Future<Budget> getBudget(String budgetId) async {
    return await _apiService.getBudget(budgetId);
  }

  /// Crea un nuevo presupuesto.
  /// Valida que startDate < endDate y que amount > 0.
  Future<Budget> createBudget({
    required String name,
    String? category,
    required double amount,
    required String period,
    required DateTime startDate,
    required DateTime endDate,
    String? currency,
    bool? isRecurring,
    bool? allowRollover,
    List<int>? alertThresholds,
    Map<String, bool>? notificationChannels,
  }) async {
    // Validaciones locales
    if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(startDate)) {
      throw Exception('End date must be after start date');
    }
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }

    final budgetData = {
      'name': name,
      if (category != null) 'category': category,
      'amount': amount,
      'period': period,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      if (currency != null) 'currency': currency,
      if (isRecurring != null) 'isRecurring': isRecurring,
      if (allowRollover != null) 'allowRollover': allowRollover,
      if (alertThresholds != null) 'alertThresholds': alertThresholds,
      if (notificationChannels != null) 'notificationChannels': notificationChannels,
    };

    return await _apiService.createBudget(budgetData);
  }

  /// Actualiza un presupuesto existente.
  /// Solo se pueden actualizar presupuestos que no hayan expirado.
  Future<Budget> updateBudget({
    required String budgetId,
    String? name,
    String? category,
    double? amount,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
    bool? isActive,
    bool? isRecurring,
    bool? allowRollover,
    List<int>? alertThresholds,
    Map<String, bool>? notificationChannels,
  }) async {
    // Validar fechas si se proveen ambas
    if (startDate != null && endDate != null) {
      if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(startDate)) {
        throw Exception('End date must be after start date');
      }
    }

    final budgetData = <String, dynamic>{
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (isActive != null) 'isActive': isActive,
      if (isRecurring != null) 'isRecurring': isRecurring,
      if (allowRollover != null) 'allowRollover': allowRollover,
      if (alertThresholds != null) 'alertThresholds': alertThresholds,
      if (notificationChannels != null) 'notificationChannels': notificationChannels,
    };

    return await _apiService.updateBudget(budgetId, budgetData);
  }

  /// Elimina un presupuesto.
  /// También elimina todas las alertas asociadas en cascada.
  Future<void> deleteBudget(String budgetId) async {
    await _apiService.deleteBudget(budgetId);
  }

  /// Duplica un presupuesto existente con nuevas fechas.
  /// Útil para crear presupuestos similares en diferentes períodos.
  Future<Budget> duplicateBudget({
    required String budgetId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(startDate)) {
      throw Exception('End date must be after start date');
    }

    final response = await _apiService.duplicateBudget(
      id: budgetId,
      startDate: startDate,
      endDate: endDate,
    );

    return Budget.fromJson(response as Map<String, dynamic>);
  }

  // ============================================================================
  // BUDGETS - Progress & Analytics
  // ============================================================================

  /// Obtiene el progreso detallado de un presupuesto.
  /// Incluye spending actual, porcentaje, días restantes y proyecciones.
  Future<BudgetProgress> getBudgetProgress(String budgetId) async {
    final response = await _apiService.getBudgetProgress(budgetId);
    print('DEBUG: Budget progress response: $response');
    final progress = BudgetProgress.fromJson(response as Map<String, dynamic>);
    print('DEBUG: Parsed progress - currentSpending: ${progress.currentSpending}, percentage: ${progress.percentage}');
    return progress;
  }

  /// Obtiene un resumen de todos los presupuestos activos del usuario.
  /// Agrupa por categoría y muestra totales.
  Future<Map<String, dynamic>> getBudgetsSummary() async {
    final response = await _apiService.getBudgetsSummary();
    return response as Map<String, dynamic>;
  }

  /// Obtiene insights y recomendaciones basadas en el comportamiento del usuario.
  /// Incluye sugerencias de ahorro, categorías problemáticas, etc.
  Future<List<Map<String, dynamic>>> getBudgetInsights(String budgetId) async {
    final response = await _apiService.getBudgetInsights(budgetId);
    return response.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Obtiene predicciones sobre el gasto futuro basadas en el comportamiento actual.
  /// Usa ML-style analytics para estimar si se excederá el presupuesto.
  Future<Map<String, dynamic>> getBudgetPredictions(String budgetId) async {
    final response = await _apiService.getBudgetPredictions(budgetId);
    return response as Map<String, dynamic>;
  }

  /// Obtiene el histórico mensual de gastos y proyección para un presupuesto.
  /// Incluye datos de los últimos [months] meses y proyección para el mes actual.
  /// mode: 'cumulative' para serie acumulada del mes actual; sparse: sólo días con recibos.
  Future<Map<String, dynamic>> getBudgetSpendingTrend(
    String budgetId, {
    int months = 6,
    String mode = 'cumulative',
    bool sparse = true,
  }) async {
    final response = await _apiService.getBudgetSpendingTrend(
      budgetId,
      months: months,
      mode: mode,
      sparse: sparse,
    );
    try {
      final cm = (response['currentMonth'] as Map<String, dynamic>?);
      final dp = (cm != null ? cm['dailyPoints'] as List<dynamic>? : null)?.length ?? 0;
      final hm = (response['historicalMonths'] as List<dynamic>?)?.length ??
          (response['historicalData'] as List<dynamic>?)?.length ?? 0;
      final proj = (response['projection'] as Map<String, dynamic>?)?['projectedTotal'];
      // Debug para verificar payload recibido
      // ignore: avoid_print
      print('DEBUG: SpendingTrend months=$hm, dailyPoints=$dp, projection=$proj');
    } catch (_) {}
    return response as Map<String, dynamic>;
  }

  // ============================================================================
  // ALERTS - Management
  // ============================================================================

  /// Obtiene las alertas de un presupuesto.
  /// Soporta filtrado por presupuesto y estado de lectura.
  Future<List<BudgetAlert>> getBudgetAlerts({
    String? budgetId,
    bool? unreadOnly,
    int? limit,
  }) async {
    final response = await _apiService.getBudgetAlerts(
      budgetId: budgetId,
      unreadOnly: unreadOnly,
      limit: limit,
    );

    final alerts = response['alerts'] as List<dynamic>;
    return alerts.map((json) => BudgetAlert.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Marca una alerta como leída.
  Future<void> markAlertAsRead(String alertId) async {
    await _apiService.markAlertAsRead(alertId);
  }

  /// Marca todas las alertas del usuario como leídas.
  Future<void> markAllAlertsAsRead() async {
    await _apiService.markAllAlertsAsRead();
  }

  /// Obtiene estadísticas sobre las alertas del usuario.
  /// Incluye conteos por tipo y estado de lectura.
  Future<Map<String, dynamic>> getAlertStats() async {
    final response = await _apiService.getAlertStats();
    return response as Map<String, dynamic>;
  }

  // ============================================================================
  // NOTIFICATIONS - Preferences & FCM
  // ============================================================================

  /// Obtiene las preferencias de notificación del usuario.
  /// Si no existen, se crean con valores por defecto.
  Future<NotificationPreference> getNotificationPreferences() async {
    final response = await _apiService.getNotificationPreferences();
    return NotificationPreference.fromJson(
      response['preferences'] as Map<String, dynamic>
    );
  }

  /// Actualiza las preferencias de notificación completas.
  Future<NotificationPreference> updateNotificationPreferences({
    bool? budgetAlerts,
    bool? receiptProcessing,
    bool? weeklyDigest,
    bool? monthlyDigest,
    bool? priceAlerts,
    bool? productRecommendations,
  }) async {
    final response = await _apiService.updateNotificationPreferences(
      budgetAlerts: budgetAlerts,
      receiptProcessing: receiptProcessing,
      weeklyDigest: weeklyDigest,
      monthlyDigest: monthlyDigest,
      priceAlerts: priceAlerts,
      productRecommendations: productRecommendations,
    );

    return NotificationPreference.fromJson(
      (response['preferences'] as Map<String, dynamic>)
    );
  }

  /// Registra el token FCM del dispositivo para recibir push notifications.
  /// Este método debe llamarse después de obtener el token de Firebase.
  Future<void> registerFCMToken(String fcmToken) async {
    if (fcmToken.isEmpty || fcmToken.length < 10 || fcmToken.length > 500) {
      throw Exception('Invalid FCM token format');
    }

    await _apiService.registerFCMToken(fcmToken: fcmToken);
  }

  /// Elimina el token FCM del dispositivo.
  /// Llamar al cerrar sesión o desinstalar la app.
  Future<void> removeFCMToken() async {
    await _apiService.removeFCMToken();
  }

  /// Actualiza solo los canales de notificación (push, email, in-app).
  Future<void> updateNotificationChannels({
    required Map<String, bool> channels,
  }) async {
    await _apiService.updateNotificationChannels(
      channels: channels,
    );
  }

  /// Configura el horario de silencio (quiet hours).
  /// Durante estas horas no se envían notificaciones push.
  Future<void> setQuietHours({
    required bool enabled,
    int? start,
    int? end,
  }) async {
    await _apiService.setQuietHours(enabled: enabled, start: start, end: end);
  }

  /// Actualiza la configuración del digest (resumen periódico).
  Future<void> updateDigestSettings({
    String? frequency,
    int? day,
    int? hour,
    bool? weeklyEnabled,
    bool? monthlyEnabled,
  }) async {
    await _apiService.updateDigestSettings(
      frequency: frequency,
      day: day,
      hour: hour,
      weeklyEnabled: weeklyEnabled,
      monthlyEnabled: monthlyEnabled,
    );
  }

  /// Envía una notificación de prueba para verificar la configuración.
  Future<void> sendTestNotification() async {
    await _apiService.sendTestNotification();
  }

  /// Obtiene el estado de FCM del usuario (si tiene tokens registrados).
  Future<Map<String, dynamic>> getFCMStatus() async {
    final response = await _apiService.getFCMStatus();
    return response['status'] as Map<String, dynamic>;
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Calcula el progreso de un presupuesto localmente (sin llamar al API).
  /// Útil para mostrar progreso en tiempo real en la UI.
  double calculateProgressPercentage(double spent, double total) {
    if (total <= 0) return 0.0;
    return ((spent / total) * 100).clamp(0.0, 200.0); // Max 200% para over-budget
  }

  /// Determina el color del progreso según el porcentaje.
  /// Verde: < 70%, Amarillo: 70-90%, Naranja: 90-100%, Rojo: > 100%
  String getProgressColor(double percentage) {
    if (percentage < 70) return 'green';
    if (percentage < 90) return 'yellow';
    if (percentage < 100) return 'orange';
    return 'red';
  }

  /// Formatea una cantidad de dinero con el símbolo de moneda.
  String formatCurrency(double amount, String currency) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'MXN': '\$',
      'CAD': 'CA\$',
    };

    final symbol = symbols[currency.toUpperCase()] ?? currency;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Calcula cuántos días quedan en un presupuesto.
  int calculateDaysRemaining(DateTime endDate) {
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 0;
    return endDate.difference(now).inDays;
  }

  /// Determina si un presupuesto está actualmente activo.
  bool isBudgetActive(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Valida el formato de hora (HH:MM).
  bool _isValidTimeFormat(String time) {
    final regex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    return regex.hasMatch(time);
  }

  /// Calcula el gasto diario promedio basado en días transcurridos.
  double calculateDailyAverageSpending(double totalSpent, DateTime startDate) {
    final now = DateTime.now();
    final daysElapsed = now.difference(startDate).inDays;
    if (daysElapsed <= 0) return 0.0;
    return totalSpent / daysElapsed;
  }

  /// Proyecta el gasto total al final del período basado en el ritmo actual.
  double projectTotalSpending(
    double currentSpent,
    DateTime startDate,
    DateTime endDate,
  ) {
    final now = DateTime.now();
    final totalDays = endDate.difference(startDate).inDays;
    final daysElapsed = now.difference(startDate).inDays;

    if (daysElapsed <= 0) return 0.0;
    if (totalDays <= 0) return currentSpent;

    final dailyRate = currentSpent / daysElapsed;
    return dailyRate * totalDays;
  }

  /// Determina si se debe mostrar una alerta predictiva.
  bool shouldShowPredictiveAlert(
    double currentSpent,
    double budgetAmount,
    DateTime startDate,
    DateTime endDate,
  ) {
    final projectedSpending = projectTotalSpending(
      currentSpent,
      startDate,
      endDate,
    );

    // Mostrar alerta si se proyecta exceder el presupuesto en más de 10%
    return projectedSpending > (budgetAmount * 1.1);
  }

  /// Calcula el presupuesto diario recomendado para no exceder el límite.
  double calculateRecommendedDailyBudget(
    double budgetAmount,
    double currentSpent,
    DateTime endDate,
  ) {
    final now = DateTime.now();
    final daysRemaining = endDate.difference(now).inDays;

    if (daysRemaining <= 0) return 0.0;

    final remainingBudget = budgetAmount - currentSpent;
    if (remainingBudget <= 0) return 0.0;

    return remainingBudget / daysRemaining;
  }
}
