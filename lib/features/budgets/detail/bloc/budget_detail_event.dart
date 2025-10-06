import 'package:equatable/equatable.dart';

/// Clase base abstracta para todos los eventos del BudgetDetailBloc.
abstract class BudgetDetailEvent extends Equatable {
  const BudgetDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Evento para cargar los detalles de un presupuesto específico.
class FetchBudgetDetail extends BudgetDetailEvent {
  final String budgetId;

  const FetchBudgetDetail(this.budgetId);

  @override
  List<Object> get props => [budgetId];
}

/// Evento para refrescar los detalles del presupuesto.
class RefreshBudgetDetail extends BudgetDetailEvent {
  const RefreshBudgetDetail();
}

/// Evento para cargar el progreso del presupuesto.
class FetchBudgetProgress extends BudgetDetailEvent {
  final String budgetId;

  const FetchBudgetProgress(this.budgetId);

  @override
  List<Object> get props => [budgetId];
}

/// Evento para cargar insights del presupuesto.
class FetchBudgetInsights extends BudgetDetailEvent {
  final String budgetId;

  const FetchBudgetInsights(this.budgetId);

  @override
  List<Object> get props => [budgetId];
}

/// Evento para cargar predicciones del presupuesto.
class FetchBudgetPredictions extends BudgetDetailEvent {
  final String budgetId;

  const FetchBudgetPredictions(this.budgetId);

  @override
  List<Object> get props => [budgetId];
}

/// Evento para cargar alertas del presupuesto.
class FetchBudgetAlerts extends BudgetDetailEvent {
  final String budgetId;

  const FetchBudgetAlerts(this.budgetId);

  @override
  List<Object> get props => [budgetId];
}

/// Evento para marcar una alerta como leída.
class MarkAlertAsRead extends BudgetDetailEvent {
  final String alertId;

  const MarkAlertAsRead(this.alertId);

  @override
  List<Object> get props => [alertId];
}

/// Evento para actualizar el presupuesto.
class UpdateBudget extends BudgetDetailEvent {
  final String budgetId;
  final Map<String, dynamic> updates;

  const UpdateBudget({
    required this.budgetId,
    required this.updates,
  });

  @override
  List<Object> get props => [budgetId, updates];
}

/// Evento para activar/desactivar un presupuesto.
class ToggleBudgetStatus extends BudgetDetailEvent {
  final String budgetId;
  final bool isActive;

  const ToggleBudgetStatus({
    required this.budgetId,
    required this.isActive,
  });

  @override
  List<Object> get props => [budgetId, isActive];
}
