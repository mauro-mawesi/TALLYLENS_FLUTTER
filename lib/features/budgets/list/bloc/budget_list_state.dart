import 'package:equatable/equatable.dart';
import 'package:recibos_flutter/core/models/budget.dart';

/// Clase base abstracta para todos los estados del BudgetListBloc.
abstract class BudgetListState extends Equatable {
  const BudgetListState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial cuando no ha ocurrido nada.
class BudgetListInitial extends BudgetListState {
  const BudgetListInitial();
}

/// Estado mientras se cargan los presupuestos.
class BudgetListLoading extends BudgetListState {
  const BudgetListLoading();
}

/// Estado cuando los presupuestos se han cargado con éxito.
class BudgetListLoaded extends BudgetListState {
  final List<Budget> budgets;
  final String? categoryFilter;
  final String? periodFilter;
  final bool? isActiveFilter;
  final Map<String, dynamic>? summary;

  const BudgetListLoaded({
    required this.budgets,
    this.categoryFilter,
    this.periodFilter,
    this.isActiveFilter,
    this.summary,
  });

  /// Crea una copia del estado con los valores actualizados.
  BudgetListLoaded copyWith({
    List<Budget>? budgets,
    String? categoryFilter,
    String? periodFilter,
    bool? isActiveFilter,
    Map<String, dynamic>? summary,
    bool clearCategoryFilter = false,
    bool clearPeriodFilter = false,
    bool clearIsActiveFilter = false,
  }) {
    return BudgetListLoaded(
      budgets: budgets ?? this.budgets,
      categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      periodFilter: clearPeriodFilter ? null : (periodFilter ?? this.periodFilter),
      isActiveFilter: clearIsActiveFilter ? null : (isActiveFilter ?? this.isActiveFilter),
      summary: summary ?? this.summary,
    );
  }

  /// Retorna presupuestos filtrados localmente.
  List<Budget> get filteredBudgets {
    var filtered = budgets;

    if (categoryFilter != null && categoryFilter!.isNotEmpty) {
      filtered = filtered.where((b) => b.category == categoryFilter).toList();
    }

    if (periodFilter != null && periodFilter!.isNotEmpty) {
      filtered = filtered.where((b) => b.period == periodFilter).toList();
    }

    if (isActiveFilter != null) {
      filtered = filtered.where((b) => b.isActive == isActiveFilter).toList();
    }

    return filtered;
  }

  /// Verifica si hay filtros activos.
  bool get hasActiveFilters =>
      categoryFilter != null || periodFilter != null || isActiveFilter != null;

  @override
  List<Object?> get props => [
        budgets,
        categoryFilter,
        periodFilter,
        isActiveFilter,
        summary,
      ];
}

/// Estado cuando ha ocurrido un error al cargar los presupuestos.
class BudgetListError extends BudgetListState {
  final String message;

  const BudgetListError(this.message);

  @override
  List<Object> get props => [message];
}

/// Estado cuando se está realizando una acción (delete, duplicate).
class BudgetListActionInProgress extends BudgetListState {
  final String action;
  final String budgetId;

  const BudgetListActionInProgress({
    required this.action,
    required this.budgetId,
  });

  @override
  List<Object> get props => [action, budgetId];
}

/// Estado cuando una acción se completó con éxito.
class BudgetListActionSuccess extends BudgetListState {
  final String message;
  final List<Budget> budgets;

  const BudgetListActionSuccess({
    required this.message,
    required this.budgets,
  });

  @override
  List<Object> get props => [message, budgets];
}

/// Estado cuando una acción falló.
class BudgetListActionError extends BudgetListState {
  final String message;
  final List<Budget> budgets;

  const BudgetListActionError({
    required this.message,
    required this.budgets,
  });

  @override
  List<Object> get props => [message, budgets];
}
