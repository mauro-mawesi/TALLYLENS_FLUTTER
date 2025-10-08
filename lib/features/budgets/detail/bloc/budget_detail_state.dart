import 'package:equatable/equatable.dart';
import 'package:recibos_flutter/core/models/budget.dart';
import 'package:recibos_flutter/core/models/budget_alert.dart';

/// Clase base abstracta para todos los estados del BudgetDetailBloc.
abstract class BudgetDetailState extends Equatable {
  const BudgetDetailState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial cuando no ha ocurrido nada.
class BudgetDetailInitial extends BudgetDetailState {
  const BudgetDetailInitial();
}

/// Estado mientras se cargan los detalles del presupuesto.
class BudgetDetailLoading extends BudgetDetailState {
  const BudgetDetailLoading();
}

/// Estado cuando los detalles del presupuesto se han cargado con éxito.
class BudgetDetailLoaded extends BudgetDetailState {
  final Budget budget;
  final BudgetProgress? progress;
  final List<Map<String, dynamic>>? insights;
  final Map<String, dynamic>? predictions;
  final List<BudgetAlert>? alerts;
  final Map<String, dynamic>? spendingTrend;
  final bool isRefreshing;

  const BudgetDetailLoaded({
    required this.budget,
    this.progress,
    this.insights,
    this.predictions,
    this.alerts,
    this.spendingTrend,
    this.isRefreshing = false,
  });

  /// Crea una copia del estado con los valores actualizados.
  BudgetDetailLoaded copyWith({
    Budget? budget,
    BudgetProgress? progress,
    List<Map<String, dynamic>>? insights,
    Map<String, dynamic>? predictions,
    List<BudgetAlert>? alerts,
    Map<String, dynamic>? spendingTrend,
    bool? isRefreshing,
  }) {
    return BudgetDetailLoaded(
      budget: budget ?? this.budget,
      progress: progress ?? this.progress,
      insights: insights ?? this.insights,
      predictions: predictions ?? this.predictions,
      alerts: alerts ?? this.alerts,
      spendingTrend: spendingTrend ?? this.spendingTrend,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Verifica si todos los datos están cargados.
  bool get isFullyLoaded =>
      progress != null &&
      insights != null &&
      predictions != null &&
      alerts != null;

  /// Cuenta de alertas no leídas.
  int get unreadAlertsCount =>
      alerts?.where((a) => !a.wasRead).length ?? 0;

  /// Alertas recientes (últimas 24 horas).
  List<BudgetAlert> get recentAlerts {
    if (alerts == null) return [];
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    return alerts!.where((a) => a.createdAt.isAfter(yesterday)).toList();
  }

  @override
  List<Object?> get props => [
        budget,
        progress,
        insights,
        predictions,
        alerts,
        spendingTrend,
        isRefreshing,
      ];
}

/// Estado cuando ha ocurrido un error al cargar los detalles.
class BudgetDetailError extends BudgetDetailState {
  final String message;

  const BudgetDetailError(this.message);

  @override
  List<Object> get props => [message];
}

/// Estado cuando se está cargando el progreso.
class BudgetDetailProgressLoading extends BudgetDetailState {
  final Budget budget;

  const BudgetDetailProgressLoading(this.budget);

  @override
  List<Object> get props => [budget];
}

/// Estado cuando se están cargando los insights.
class BudgetDetailInsightsLoading extends BudgetDetailState {
  final Budget budget;
  final BudgetProgress? progress;

  const BudgetDetailInsightsLoading({
    required this.budget,
    this.progress,
  });

  @override
  List<Object?> get props => [budget, progress];
}

/// Estado cuando se están cargando las predicciones.
class BudgetDetailPredictionsLoading extends BudgetDetailState {
  final Budget budget;
  final BudgetProgress? progress;
  final List<Map<String, dynamic>>? insights;

  const BudgetDetailPredictionsLoading({
    required this.budget,
    this.progress,
    this.insights,
  });

  @override
  List<Object?> get props => [budget, progress, insights];
}

/// Estado cuando se están cargando las alertas.
class BudgetDetailAlertsLoading extends BudgetDetailState {
  final Budget budget;
  final BudgetProgress? progress;
  final List<Map<String, dynamic>>? insights;
  final Map<String, dynamic>? predictions;

  const BudgetDetailAlertsLoading({
    required this.budget,
    this.progress,
    this.insights,
    this.predictions,
  });

  @override
  List<Object?> get props => [budget, progress, insights, predictions];
}

/// Estado cuando se está realizando una actualización.
class BudgetDetailUpdating extends BudgetDetailState {
  final Budget budget;

  const BudgetDetailUpdating(this.budget);

  @override
  List<Object> get props => [budget];
}

/// Estado cuando una actualización se completó con éxito.
class BudgetDetailUpdateSuccess extends BudgetDetailState {
  final String message;
  final Budget budget;

  const BudgetDetailUpdateSuccess({
    required this.message,
    required this.budget,
  });

  @override
  List<Object> get props => [message, budget];
}

/// Estado cuando una actualización falló.
class BudgetDetailUpdateError extends BudgetDetailState {
  final String message;
  final Budget budget;

  const BudgetDetailUpdateError({
    required this.message,
    required this.budget,
  });

  @override
  List<Object> get props => [message, budget];
}
