import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/budget_service.dart';
import 'package:recibos_flutter/core/models/budget_alert.dart';
import 'package:recibos_flutter/core/models/notification_preference.dart';
import 'notifications_state.dart';

/// Cubit para gestionar el notification center y preferencias de notificaciones.
/// Maneja alertas, preferencias y tokens FCM.
class NotificationsCubit extends Cubit<NotificationsState> {
  final BudgetService _budgetService;

  NotificationsCubit({
    required BudgetService budgetService,
  })  : _budgetService = budgetService,
        super(const NotificationsInitial());

  /// Carga las notificaciones y preferencias.
  Future<void> loadNotifications({
    String? budgetId,
    bool? unreadOnly,
    int? limit,
  }) async {
    try {
      emit(const NotificationsLoading());

      // Cargar alerts, preferencias y stats en paralelo
      final results = await Future.wait([
        _budgetService.getBudgetAlerts(
          budgetId: budgetId,
          unreadOnly: unreadOnly,
          limit: limit ?? 50,
        ),
        _budgetService.getNotificationPreferences().catchError((e) {
          print('Error loading preferences: $e');
          return null;
        }),
        _budgetService.getAlertStats().catchError((e) {
          print('Error loading stats: $e');
          return <String, dynamic>{};
        }),
      ]);

      final alerts = results[0] as List<BudgetAlert>;
      final preferences = results[1] as NotificationPreference?;
      final stats = results[2] as Map<String, dynamic>;

      emit(NotificationsLoaded(
        alerts: alerts,
        preferences: preferences,
        stats: stats,
      ));
    } catch (e) {
      emit(NotificationsError('Error loading notifications: ${e.toString()}'));
    }
  }

  /// Refresca las notificaciones.
  Future<void> refreshNotifications() async {
    final currentState = state;

    if (currentState is! NotificationsLoaded) {
      // Si no está cargado, hacer carga inicial
      await loadNotifications();
      return;
    }

    try {
      // Marcar como refrescando
      emit(currentState.copyWith(isRefreshing: true));

      // Recargar datos en paralelo
      final results = await Future.wait([
        _budgetService.getBudgetAlerts(limit: 50),
        _budgetService.getNotificationPreferences(),
        _budgetService.getAlertStats(),
      ]);

      final alerts = results[0] as List<BudgetAlert>;
      final preferences = results[1] as NotificationPreference;
      final stats = results[2] as Map<String, dynamic>;

      emit(NotificationsLoaded(
        alerts: alerts,
        preferences: preferences,
        stats: stats,
        isRefreshing: false,
      ));
    } catch (e) {
      // Mantener el estado actual en caso de error
      emit(currentState.copyWith(isRefreshing: false));
    }
  }

  /// Marca una alerta como leída.
  Future<void> markAlertAsRead(String alertId) async {
    final currentState = state;
    if (currentState is! NotificationsLoaded) return;

    try {
      await _budgetService.markAlertAsRead(alertId);

      // Actualizar lista local
      final updatedAlerts = currentState.alerts.map((alert) {
        if (alert.id == alertId) {
          return alert.copyWith(
            wasRead: true,
            readAt: DateTime.now(),
          );
        }
        return alert;
      }).toList();

      // Actualizar stats
      final stats = await _budgetService.getAlertStats();

      emit(currentState.copyWith(
        alerts: updatedAlerts,
        stats: stats,
      ));
    } catch (e) {
      print('Error marking alert as read: $e');
    }
  }

  /// Marca todas las alertas como leídas.
  Future<void> markAllAlertsAsRead() async {
    final currentState = state;
    if (currentState is! NotificationsLoaded) return;

    try {
      await _budgetService.markAllAlertsAsRead();

      // Actualizar lista local
      final updatedAlerts = currentState.alerts.map((alert) {
        return alert.copyWith(
          wasRead: true,
          readAt: DateTime.now(),
        );
      }).toList();

      // Actualizar stats
      final stats = await _budgetService.getAlertStats();

      emit(currentState.copyWith(
        alerts: updatedAlerts,
        stats: stats,
      ));
    } catch (e) {
      print('Error marking all alerts as read: $e');
    }
  }

  /// Filtra notificaciones por presupuesto.
  Future<void> filterByBudget(String? budgetId) async {
    await loadNotifications(budgetId: budgetId);
  }

  /// Filtra notificaciones por estado de lectura.
  Future<void> filterByReadStatus(bool? unreadOnly) async {
    await loadNotifications(unreadOnly: unreadOnly);
  }

  // ============================================================================
  // NOTIFICATION PREFERENCES
  // ============================================================================

  /// Carga las preferencias de notificación.
  Future<void> loadPreferences() async {
    try {
      final preferences = await _budgetService.getNotificationPreferences();

      final currentState = state;
      if (currentState is NotificationsLoaded) {
        emit(currentState.copyWith(preferences: preferences));
      } else {
        emit(NotificationsLoaded(
          alerts: const [],
          preferences: preferences,
        ));
      }
    } catch (e) {
      emit(NotificationsError('Error loading preferences: ${e.toString()}'));
    }
  }

  /// Actualiza las preferencias de notificación.
  Future<void> updatePreferences({
    bool? budgetAlerts,
    bool? receiptProcessing,
    bool? weeklyDigest,
    bool? monthlyDigest,
    bool? priceAlerts,
    bool? productRecommendations,
  }) async {
    final currentState = state;
    final currentPreferences = currentState is NotificationsLoaded
        ? currentState.preferences
        : null;

    if (currentPreferences == null) {
      emit(const NotificationsPreferencesError(
        message: 'No preferences loaded',
      ));
      return;
    }

    try {
      emit(NotificationsPreferencesUpdating(currentPreferences));

      final updatedPreferences = await _budgetService.updateNotificationPreferences(
        budgetAlerts: budgetAlerts,
        receiptProcessing: receiptProcessing,
        weeklyDigest: weeklyDigest,
        monthlyDigest: monthlyDigest,
        priceAlerts: priceAlerts,
        productRecommendations: productRecommendations,
      );

      emit(NotificationsPreferencesUpdated(
        preferences: updatedPreferences,
        message: 'Preferences updated successfully',
      ));

      // Volver al estado loaded
      if (currentState is NotificationsLoaded) {
        emit(currentState.copyWith(preferences: updatedPreferences));
      }
    } catch (e) {
      emit(NotificationsPreferencesError(
        message: 'Error updating preferences: ${e.toString()}',
        currentPreferences: currentPreferences,
      ));

      // Volver al estado anterior
      if (currentState is NotificationsLoaded) {
        emit(currentState);
      }
    }
  }

  /// Actualiza solo los canales de notificación.
  Future<void> updateChannels({
    required Map<String, bool> channels,
  }) async {
    final currentState = state;
    final currentPreferences = currentState is NotificationsLoaded
        ? currentState.preferences
        : null;

    if (currentPreferences == null) return;

    try {
      emit(NotificationsPreferencesUpdating(currentPreferences));

      await _budgetService.updateNotificationChannels(
        channels: channels,
      );

      // Recargar preferencias para obtener el estado actualizado
      await loadPreferences();
    } catch (e) {
      emit(NotificationsPreferencesError(
        message: 'Error updating channels: ${e.toString()}',
        currentPreferences: currentPreferences,
      ));

      if (currentState is NotificationsLoaded) {
        emit(currentState);
      }
    }
  }

  /// Configura el horario de silencio (quiet hours).
  Future<void> setQuietHours({
    required bool enabled,
    int? start,
    int? end,
  }) async {
    final currentState = state;
    final currentPreferences = currentState is NotificationsLoaded
        ? currentState.preferences
        : null;

    if (currentPreferences == null) return;

    try {
      emit(NotificationsPreferencesUpdating(currentPreferences));

      await _budgetService.setQuietHours(
        enabled: enabled,
        start: start,
        end: end,
      );

      // Recargar preferencias para obtener el estado actualizado
      await loadPreferences();
    } catch (e) {
      emit(NotificationsPreferencesError(
        message: 'Error setting quiet hours: ${e.toString()}',
        currentPreferences: currentPreferences,
      ));

      if (currentState is NotificationsLoaded) {
        emit(currentState);
      }
    }
  }

  /// Actualiza la configuración del digest.
  Future<void> updateDigestSettings({
    String? frequency,
    int? day,
    int? hour,
    bool? weeklyEnabled,
    bool? monthlyEnabled,
  }) async {
    final currentState = state;
    final currentPreferences = currentState is NotificationsLoaded
        ? currentState.preferences
        : null;

    if (currentPreferences == null) return;

    try {
      emit(NotificationsPreferencesUpdating(currentPreferences));

      await _budgetService.updateDigestSettings(
        frequency: frequency,
        day: day,
        hour: hour,
        weeklyEnabled: weeklyEnabled,
        monthlyEnabled: monthlyEnabled,
      );

      // Recargar preferencias para obtener el estado actualizado
      await loadPreferences();
    } catch (e) {
      emit(NotificationsPreferencesError(
        message: 'Error updating digest: ${e.toString()}',
        currentPreferences: currentPreferences,
      ));

      if (currentState is NotificationsLoaded) {
        emit(currentState);
      }
    }
  }

  // ============================================================================
  // FCM TOKEN MANAGEMENT
  // ============================================================================

  /// Registra el token FCM del dispositivo.
  Future<void> registerFCMToken(String fcmToken) async {
    try {
      emit(const NotificationsFCMTokenUpdating('register'));

      await _budgetService.registerFCMToken(fcmToken);

      emit(const NotificationsFCMTokenUpdated(
        message: 'FCM token registered successfully',
        action: 'register',
      ));

      // Recargar preferencias para actualizar el estado
      await loadPreferences();
    } catch (e) {
      emit(NotificationsFCMTokenError(
        'Error registering FCM token: ${e.toString()}',
      ));
    }
  }

  /// Elimina el token FCM del dispositivo.
  Future<void> removeFCMToken() async {
    try {
      emit(const NotificationsFCMTokenUpdating('remove'));

      await _budgetService.removeFCMToken();

      emit(const NotificationsFCMTokenUpdated(
        message: 'FCM token removed successfully',
        action: 'remove',
      ));

      // Recargar preferencias para actualizar el estado
      await loadPreferences();
    } catch (e) {
      emit(NotificationsFCMTokenError(
        'Error removing FCM token: ${e.toString()}',
      ));
    }
  }

  /// Envía una notificación de prueba.
  Future<void> sendTestNotification() async {
    try {
      await _budgetService.sendTestNotification();
      // La notificación de prueba se recibirá a través de FCM
    } catch (e) {
      emit(NotificationsError(
        'Error sending test notification: ${e.toString()}',
      ));
    }
  }
}
