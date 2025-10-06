import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/budget_service.dart';
import 'package:recibos_flutter/core/models/budget.dart';
import 'package:recibos_flutter/core/models/budget_alert.dart';
import 'budget_detail_event.dart';
import 'budget_detail_state.dart';

/// BLoC para gestionar los detalles de un presupuesto específico.
/// Maneja la carga de datos del presupuesto, progreso, insights, predicciones y alertas.
class BudgetDetailBloc extends Bloc<BudgetDetailEvent, BudgetDetailState> {
  final BudgetService _budgetService;

  String? _currentBudgetId;

  BudgetDetailBloc({
    required BudgetService budgetService,
  })  : _budgetService = budgetService,
        super(const BudgetDetailInitial()) {
    on<FetchBudgetDetail>(_onFetchBudgetDetail);
    on<RefreshBudgetDetail>(_onRefreshBudgetDetail);
    on<FetchBudgetProgress>(_onFetchBudgetProgress);
    on<FetchBudgetInsights>(_onFetchBudgetInsights);
    on<FetchBudgetPredictions>(_onFetchBudgetPredictions);
    on<FetchBudgetAlerts>(_onFetchBudgetAlerts);
    on<MarkAlertAsRead>(_onMarkAlertAsRead);
    on<UpdateBudget>(_onUpdateBudget);
    on<ToggleBudgetStatus>(_onToggleBudgetStatus);
  }

  /// Carga los detalles completos de un presupuesto.
  /// Incluye: budget, progress, insights, predictions, alerts.
  Future<void> _onFetchBudgetDetail(
    FetchBudgetDetail event,
    Emitter<BudgetDetailState> emit,
  ) async {
    _currentBudgetId = event.budgetId;

    try {
      emit(const BudgetDetailLoading());

      // 1. Cargar presupuesto básico primero
      final budget = await _budgetService.getBudget(event.budgetId);

      // 2. Emitir estado inicial con el presupuesto
      emit(BudgetDetailLoaded(budget: budget));

      // 3. Cargar progreso
      try {
        final progress = await _budgetService.getBudgetProgress(event.budgetId);
        final currentState = state as BudgetDetailLoaded;
        emit(currentState.copyWith(progress: progress));
      } catch (e) {
        // Si falla el progreso, continuar con los demás datos
        print('Error loading progress: $e');
      }

      // 4. Cargar insights en paralelo con predictions y alerts
      final results = await Future.wait([
        _budgetService.getBudgetInsights(event.budgetId).catchError((e) {
          print('Error loading insights: $e');
          return <Map<String, dynamic>>[];
        }),
        _budgetService.getBudgetPredictions(event.budgetId).catchError((e) {
          print('Error loading predictions: $e');
          return <String, dynamic>{};
        }),
        _budgetService.getBudgetAlerts(budgetId: event.budgetId).catchError((e) {
          print('Error loading alerts: $e');
          return <BudgetAlert>[];
        }),
      ]);

      final insights = results[0] as List<Map<String, dynamic>>;
      final predictions = results[1] as Map<String, dynamic>;
      final alerts = results[2] as List<BudgetAlert>;

      // 5. Emitir estado final con todos los datos
      final currentState = state as BudgetDetailLoaded;
      emit(currentState.copyWith(
        insights: insights,
        predictions: predictions,
        alerts: alerts,
      ));
    } catch (e) {
      emit(BudgetDetailError('Error loading budget: ${e.toString()}'));
    }
  }

  /// Refresca los detalles del presupuesto.
  Future<void> _onRefreshBudgetDetail(
    RefreshBudgetDetail event,
    Emitter<BudgetDetailState> emit,
  ) async {
    if (_currentBudgetId == null) return;
    final currentState = state;

    if (currentState is! BudgetDetailLoaded) return;

    try {
      // Marcar como refrescando
      emit(currentState.copyWith(isRefreshing: true));

      // Recargar todos los datos en paralelo
      final results = await Future.wait([
        _budgetService.getBudget(_currentBudgetId!),
        _budgetService.getBudgetProgress(_currentBudgetId!),
        _budgetService.getBudgetInsights(_currentBudgetId!),
        _budgetService.getBudgetPredictions(_currentBudgetId!),
        _budgetService.getBudgetAlerts(budgetId: _currentBudgetId!),
      ]);

      final budget = results[0] as Budget;
      final progress = results[1] as BudgetProgress;
      final insights = results[2] as List<Map<String, dynamic>>;
      final predictions = results[3] as Map<String, dynamic>;
      final alerts = results[4] as List<BudgetAlert>;

      // Emitir estado actualizado
      emit(BudgetDetailLoaded(
        budget: budget,
        progress: progress,
        insights: insights,
        predictions: predictions,
        alerts: alerts,
        isRefreshing: false,
      ));
    } catch (e) {
      // En caso de error, mantener el estado actual
      emit(currentState.copyWith(isRefreshing: false));
    }
  }

  /// Carga solo el progreso del presupuesto.
  Future<void> _onFetchBudgetProgress(
    FetchBudgetProgress event,
    Emitter<BudgetDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BudgetDetailLoaded) return;

    try {
      final progress = await _budgetService.getBudgetProgress(event.budgetId);
      emit(currentState.copyWith(progress: progress));
    } catch (e) {
      // Mantener el estado actual en caso de error
      print('Error fetching budget progress: $e');
    }
  }

  /// Carga solo los insights del presupuesto.
  Future<void> _onFetchBudgetInsights(
    FetchBudgetInsights event,
    Emitter<BudgetDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BudgetDetailLoaded) return;

    try {
      final insights = await _budgetService.getBudgetInsights(event.budgetId);
      emit(currentState.copyWith(insights: insights));
    } catch (e) {
      print('Error fetching budget insights: $e');
    }
  }

  /// Carga solo las predicciones del presupuesto.
  Future<void> _onFetchBudgetPredictions(
    FetchBudgetPredictions event,
    Emitter<BudgetDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BudgetDetailLoaded) return;

    try {
      final predictions = await _budgetService.getBudgetPredictions(event.budgetId);
      emit(currentState.copyWith(predictions: predictions));
    } catch (e) {
      print('Error fetching budget predictions: $e');
    }
  }

  /// Carga solo las alertas del presupuesto.
  Future<void> _onFetchBudgetAlerts(
    FetchBudgetAlerts event,
    Emitter<BudgetDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BudgetDetailLoaded) return;

    try {
      final alerts = await _budgetService.getBudgetAlerts(
        budgetId: event.budgetId,
      );
      emit(currentState.copyWith(alerts: alerts));
    } catch (e) {
      print('Error fetching budget alerts: $e');
    }
  }

  /// Marca una alerta como leída.
  Future<void> _onMarkAlertAsRead(
    MarkAlertAsRead event,
    Emitter<BudgetDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BudgetDetailLoaded || currentState.alerts == null) {
      return;
    }

    try {
      await _budgetService.markAlertAsRead(event.alertId);

      // Actualizar la lista de alertas localmente
      final updatedAlerts = currentState.alerts!.map((alert) {
        if (alert.id == event.alertId) {
          return alert.copyWith(
            wasRead: true,
            readAt: DateTime.now(),
          );
        }
        return alert;
      }).toList();

      emit(currentState.copyWith(alerts: updatedAlerts));
    } catch (e) {
      print('Error marking alert as read: $e');
    }
  }

  /// Actualiza el presupuesto.
  Future<void> _onUpdateBudget(
    UpdateBudget event,
    Emitter<BudgetDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BudgetDetailLoaded) return;

    try {
      emit(BudgetDetailUpdating(currentState.budget));

      final updatedBudget = await _budgetService.updateBudget(
        budgetId: event.budgetId,
        name: event.updates['name'] as String?,
        category: event.updates['category'] as String?,
        amount: event.updates['amount'] as double?,
        period: event.updates['period'] as String?,
        startDate: event.updates['startDate'] as DateTime?,
        endDate: event.updates['endDate'] as DateTime?,
        currency: event.updates['currency'] as String?,
        isActive: event.updates['isActive'] as bool?,
        isRecurring: event.updates['isRecurring'] as bool?,
        allowRollover: event.updates['allowRollover'] as bool?,
        alertThresholds: event.updates['alertThresholds'] as List<int>?,
        notificationChannels: event.updates['notificationChannels'] as Map<String, bool>?,
      );

      emit(BudgetDetailUpdateSuccess(
        message: 'Budget updated successfully',
        budget: updatedBudget,
      ));

      // Recargar progreso e insights con el presupuesto actualizado
      add(FetchBudgetProgress(updatedBudget.id));
      add(FetchBudgetInsights(updatedBudget.id));
      add(FetchBudgetPredictions(updatedBudget.id));

      // Volver al estado loaded
      emit(currentState.copyWith(budget: updatedBudget));
    } catch (e) {
      emit(BudgetDetailUpdateError(
        message: 'Error updating budget: ${e.toString()}',
        budget: currentState.budget,
      ));

      // Volver al estado loaded original
      emit(currentState);
    }
  }

  /// Activa o desactiva un presupuesto.
  Future<void> _onToggleBudgetStatus(
    ToggleBudgetStatus event,
    Emitter<BudgetDetailState> emit,
  ) async {
    add(UpdateBudget(
      budgetId: event.budgetId,
      updates: {'isActive': event.isActive},
    ));
  }
}
