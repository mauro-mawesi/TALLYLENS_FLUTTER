import 'package:equatable/equatable.dart';
import 'package:recibos_flutter/core/models/budget_alert.dart';
import 'package:recibos_flutter/core/models/notification_preference.dart';

/// Clase base abstracta para todos los estados del NotificationsCubit.
abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial cuando no ha ocurrido nada.
class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

/// Estado mientras se cargan las notificaciones.
class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

/// Estado cuando las notificaciones se han cargado con éxito.
class NotificationsLoaded extends NotificationsState {
  final List<BudgetAlert> alerts;
  final NotificationPreference? preferences;
  final Map<String, dynamic>? stats;
  final bool isRefreshing;

  const NotificationsLoaded({
    required this.alerts,
    this.preferences,
    this.stats,
    this.isRefreshing = false,
  });

  /// Crea una copia del estado con los valores actualizados.
  NotificationsLoaded copyWith({
    List<BudgetAlert>? alerts,
    NotificationPreference? preferences,
    Map<String, dynamic>? stats,
    bool? isRefreshing,
  }) {
    return NotificationsLoaded(
      alerts: alerts ?? this.alerts,
      preferences: preferences ?? this.preferences,
      stats: stats ?? this.stats,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Cuenta de alertas no leídas.
  int get unreadCount => alerts.where((a) => !a.wasRead).length;

  /// Alertas no leídas.
  List<BudgetAlert> get unreadAlerts => alerts.where((a) => !a.wasRead).toList();

  /// Alertas leídas.
  List<BudgetAlert> get readAlerts => alerts.where((a) => a.wasRead).toList();

  /// Alertas recientes (últimas 24 horas).
  List<BudgetAlert> get recentAlerts {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    return alerts.where((a) => a.createdAt.isAfter(yesterday)).toList();
  }

  /// Alertas agrupadas por tipo.
  Map<String, List<BudgetAlert>> get alertsByType {
    final grouped = <String, List<BudgetAlert>>{};
    for (final alert in alerts) {
      grouped.putIfAbsent(alert.alertType, () => []).add(alert);
    }
    return grouped;
  }

  @override
  List<Object?> get props => [alerts, preferences, stats, isRefreshing];
}

/// Estado cuando ha ocurrido un error al cargar las notificaciones.
class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object> get props => [message];
}

/// Estado cuando se están actualizando las preferencias.
class NotificationsPreferencesUpdating extends NotificationsState {
  final NotificationPreference currentPreferences;

  const NotificationsPreferencesUpdating(this.currentPreferences);

  @override
  List<Object> get props => [currentPreferences];
}

/// Estado cuando las preferencias se actualizaron con éxito.
class NotificationsPreferencesUpdated extends NotificationsState {
  final NotificationPreference preferences;
  final String message;

  const NotificationsPreferencesUpdated({
    required this.preferences,
    required this.message,
  });

  @override
  List<Object> get props => [preferences, message];
}

/// Estado cuando falló la actualización de preferencias.
class NotificationsPreferencesError extends NotificationsState {
  final String message;
  final NotificationPreference? currentPreferences;

  const NotificationsPreferencesError({
    required this.message,
    this.currentPreferences,
  });

  @override
  List<Object?> get props => [message, currentPreferences];
}

/// Estado cuando se está registrando/eliminando el token FCM.
class NotificationsFCMTokenUpdating extends NotificationsState {
  final String action; // 'register' o 'remove'

  const NotificationsFCMTokenUpdating(this.action);

  @override
  List<Object> get props => [action];
}

/// Estado cuando el token FCM se actualizó con éxito.
class NotificationsFCMTokenUpdated extends NotificationsState {
  final String message;
  final String action;

  const NotificationsFCMTokenUpdated({
    required this.message,
    required this.action,
  });

  @override
  List<Object> get props => [message, action];
}

/// Estado cuando falló la actualización del token FCM.
class NotificationsFCMTokenError extends NotificationsState {
  final String message;

  const NotificationsFCMTokenError(this.message);

  @override
  List<Object> get props => [message];
}
