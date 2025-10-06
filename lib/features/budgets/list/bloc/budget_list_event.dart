import 'package:equatable/equatable.dart';

/// Clase base abstracta para todos los eventos del BudgetListBloc.
abstract class BudgetListEvent extends Equatable {
  const BudgetListEvent();

  @override
  List<Object?> get props => [];
}

/// Evento para cargar la lista de presupuestos.
/// Soporta filtrado por categoría, período y estado activo.
class FetchBudgets extends BudgetListEvent {
  final String? category;
  final String? period;
  final bool? isActive;
  final bool forceRefresh;

  const FetchBudgets({
    this.category,
    this.period,
    this.isActive,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [
        category,
        period,
        isActive,
        forceRefresh,
      ];
}

/// Evento para refrescar los presupuestos (pull-to-refresh).
class RefreshBudgets extends BudgetListEvent {
  const RefreshBudgets();
}

/// Evento para filtrar presupuestos por categoría.
class FilterBudgetsByCategory extends BudgetListEvent {
  final String? category;

  const FilterBudgetsByCategory(this.category);

  @override
  List<Object?> get props => [category];
}

/// Evento para filtrar presupuestos por período.
class FilterBudgetsByPeriod extends BudgetListEvent {
  final String? period;

  const FilterBudgetsByPeriod(this.period);

  @override
  List<Object?> get props => [period];
}

/// Evento para filtrar presupuestos por estado (activo/inactivo).
class FilterBudgetsByStatus extends BudgetListEvent {
  final bool? isActive;

  const FilterBudgetsByStatus(this.isActive);

  @override
  List<Object?> get props => [isActive];
}

/// Evento para limpiar todos los filtros.
class ClearBudgetFilters extends BudgetListEvent {
  const ClearBudgetFilters();
}

/// Evento para eliminar un presupuesto.
class DeleteBudget extends BudgetListEvent {
  final String budgetId;

  const DeleteBudget(this.budgetId);

  @override
  List<Object> get props => [budgetId];
}

/// Evento para duplicar un presupuesto.
class DuplicateBudget extends BudgetListEvent {
  final String budgetId;
  final DateTime startDate;
  final DateTime endDate;

  const DuplicateBudget({
    required this.budgetId,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object> get props => [budgetId, startDate, endDate];
}
