import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/budget_service.dart';
import 'package:recibos_flutter/core/models/budget.dart';
import 'budget_list_event.dart';
import 'budget_list_state.dart';

/// BLoC para gestionar la lista de presupuestos.
/// Maneja la carga, filtrado, eliminación y duplicación de presupuestos.
class BudgetListBloc extends Bloc<BudgetListEvent, BudgetListState> {
  final BudgetService _budgetService;

  // Filtros actuales
  String? _currentCategory;
  String? _currentPeriod;
  bool? _currentIsActive;

  BudgetListBloc({
    required BudgetService budgetService,
  })  : _budgetService = budgetService,
        super(const BudgetListInitial()) {
    on<FetchBudgets>(_onFetchBudgets);
    on<RefreshBudgets>(_onRefreshBudgets);
    on<FilterBudgetsByCategory>(_onFilterByCategory);
    on<FilterBudgetsByPeriod>(_onFilterByPeriod);
    on<FilterBudgetsByStatus>(_onFilterByStatus);
    on<ClearBudgetFilters>(_onClearFilters);
    on<DeleteBudget>(_onDeleteBudget);
    on<DuplicateBudget>(_onDuplicateBudget);
  }

  /// Maneja la carga inicial de presupuestos.
  Future<void> _onFetchBudgets(
    FetchBudgets event,
    Emitter<BudgetListState> emit,
  ) async {
    try {
      // Actualizar filtros
      _currentCategory = event.category;
      _currentPeriod = event.period;
      _currentIsActive = event.isActive;

      // Emitir estado de carga
      emit(const BudgetListLoading());

      // Obtener presupuestos y summary en paralelo
      final results = await Future.wait([
        _budgetService.getBudgets(
          category: _currentCategory,
          period: _currentPeriod,
          isActive: _currentIsActive,
        ),
        _budgetService.getBudgetsSummary(),
      ]);

      final budgets = results[0] as List<Budget>;
      final summary = results[1] as Map<String, dynamic>;

      // Emitir estado de éxito
      emit(BudgetListLoaded(
        budgets: budgets,
        categoryFilter: _currentCategory,
        periodFilter: _currentPeriod,
        isActiveFilter: _currentIsActive,
        summary: summary,
      ));
    } catch (e) {
      // Emitir estado de error
      emit(BudgetListError(e.toString()));
    }
  }

  /// Maneja el refresh de presupuestos (pull-to-refresh).
  Future<void> _onRefreshBudgets(
    RefreshBudgets event,
    Emitter<BudgetListState> emit,
  ) async {
    try {
      // Obtener presupuestos y summary en paralelo
      final results = await Future.wait([
        _budgetService.getBudgets(
          category: _currentCategory,
          period: _currentPeriod,
          isActive: _currentIsActive,
        ),
        _budgetService.getBudgetsSummary(),
      ]);

      final budgets = results[0] as List<Budget>;
      final summary = results[1] as Map<String, dynamic>;

      // Emitir estado actualizado
      emit(BudgetListLoaded(
        budgets: budgets,
        categoryFilter: _currentCategory,
        periodFilter: _currentPeriod,
        isActiveFilter: _currentIsActive,
        summary: summary,
      ));
    } catch (e) {
      // En caso de error en refresh, mantener el estado actual si existe
      if (state is BudgetListLoaded) {
        // Silently fail - podríamos emitir un snackbar aquí
      } else {
        emit(BudgetListError(e.toString()));
      }
    }
  }

  /// Filtra presupuestos por categoría.
  Future<void> _onFilterByCategory(
    FilterBudgetsByCategory event,
    Emitter<BudgetListState> emit,
  ) async {
    _currentCategory = event.category;
    add(FetchBudgets(
      category: _currentCategory,
      period: _currentPeriod,
      isActive: _currentIsActive,
    ));
  }

  /// Filtra presupuestos por período.
  Future<void> _onFilterByPeriod(
    FilterBudgetsByPeriod event,
    Emitter<BudgetListState> emit,
  ) async {
    _currentPeriod = event.period;
    add(FetchBudgets(
      category: _currentCategory,
      period: _currentPeriod,
      isActive: _currentIsActive,
    ));
  }

  /// Filtra presupuestos por estado (activo/inactivo).
  Future<void> _onFilterByStatus(
    FilterBudgetsByStatus event,
    Emitter<BudgetListState> emit,
  ) async {
    _currentIsActive = event.isActive;
    add(FetchBudgets(
      category: _currentCategory,
      period: _currentPeriod,
      isActive: _currentIsActive,
    ));
  }

  /// Limpia todos los filtros.
  Future<void> _onClearFilters(
    ClearBudgetFilters event,
    Emitter<BudgetListState> emit,
  ) async {
    _currentCategory = null;
    _currentPeriod = null;
    _currentIsActive = null;
    add(const FetchBudgets());
  }

  /// Elimina un presupuesto.
  Future<void> _onDeleteBudget(
    DeleteBudget event,
    Emitter<BudgetListState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BudgetListLoaded) return;

    try {
      // Emitir estado de acción en progreso
      emit(BudgetListActionInProgress(
        action: 'delete',
        budgetId: event.budgetId,
      ));

      // Eliminar presupuesto
      await _budgetService.deleteBudget(event.budgetId);

      // Actualizar lista local
      final updatedBudgets = currentState.budgets
          .where((b) => b.id != event.budgetId)
          .toList();

      // Obtener summary actualizado
      final summary = await _budgetService.getBudgetsSummary();

      // Emitir estado de éxito
      emit(BudgetListActionSuccess(
        message: 'Budget deleted successfully',
        budgets: updatedBudgets,
      ));

      // Volver al estado loaded con los datos actualizados
      emit(BudgetListLoaded(
        budgets: updatedBudgets,
        categoryFilter: _currentCategory,
        periodFilter: _currentPeriod,
        isActiveFilter: _currentIsActive,
        summary: summary,
      ));
    } catch (e) {
      // Emitir estado de error
      emit(BudgetListActionError(
        message: 'Error deleting budget: ${e.toString()}',
        budgets: currentState.budgets,
      ));

      // Volver al estado loaded original
      emit(currentState);
    }
  }

  /// Duplica un presupuesto con nuevas fechas.
  Future<void> _onDuplicateBudget(
    DuplicateBudget event,
    Emitter<BudgetListState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BudgetListLoaded) return;

    try {
      // Emitir estado de acción en progreso
      emit(BudgetListActionInProgress(
        action: 'duplicate',
        budgetId: event.budgetId,
      ));

      // Duplicar presupuesto
      final newBudget = await _budgetService.duplicateBudget(
        budgetId: event.budgetId,
        startDate: event.startDate,
        endDate: event.endDate,
      );

      // Actualizar lista local
      final updatedBudgets = [newBudget, ...currentState.budgets];

      // Obtener summary actualizado
      final summary = await _budgetService.getBudgetsSummary();

      // Emitir estado de éxito
      emit(BudgetListActionSuccess(
        message: 'Budget duplicated successfully',
        budgets: updatedBudgets,
      ));

      // Volver al estado loaded con los datos actualizados
      emit(BudgetListLoaded(
        budgets: updatedBudgets,
        categoryFilter: _currentCategory,
        periodFilter: _currentPeriod,
        isActiveFilter: _currentIsActive,
        summary: summary,
      ));
    } catch (e) {
      // Emitir estado de error
      emit(BudgetListActionError(
        message: 'Error duplicating budget: ${e.toString()}',
        budgets: currentState.budgets,
      ));

      // Volver al estado loaded original
      emit(currentState);
    }
  }
}
