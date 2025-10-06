import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/budget_service.dart';
import 'package:recibos_flutter/core/models/budget.dart';
import 'budget_form_state.dart';

/// Cubit para gestionar el formulario de creación/edición de presupuestos.
/// Maneja validación, envío y estados del formulario.
class BudgetFormCubit extends Cubit<BudgetFormState> {
  final BudgetService _budgetService;

  BudgetFormCubit({
    required BudgetService budgetService,
  })  : _budgetService = budgetService,
        super(const BudgetFormInitial());

  /// Inicializa el formulario en modo creación (nuevo presupuesto).
  void initializeForCreate() {
    emit(const BudgetFormReady());
  }

  /// Inicializa el formulario en modo edición (presupuesto existente).
  Future<void> initializeForEdit(String budgetId) async {
    try {
      emit(const BudgetFormLoading());

      final budget = await _budgetService.getBudget(budgetId);

      emit(BudgetFormReady(
        existingBudget: budget,
        isValid: true, // Ya es válido porque existe
      ));
    } catch (e) {
      emit(BudgetFormError(
        message: 'Error loading budget: ${e.toString()}',
      ));
    }
  }

  /// Valida el formulario y actualiza los errores.
  void validateForm({
    required String name,
    String? category,
    required String amountStr,
    required String period,
    required DateTime startDate,
    required DateTime endDate,
    String? currency,
    List<int>? alertThresholds,
  }) {
    final errors = <String, String>{};

    // Validar nombre
    if (name.trim().isEmpty) {
      errors['name'] = 'Name is required';
    } else if (name.trim().length < 3) {
      errors['name'] = 'Name must be at least 3 characters';
    } else if (name.trim().length > 255) {
      errors['name'] = 'Name must be less than 255 characters';
    }

    // Validar monto
    final amount = double.tryParse(amountStr);
    if (amountStr.trim().isEmpty) {
      errors['amount'] = 'Amount is required';
    } else if (amount == null) {
      errors['amount'] = 'Amount must be a valid number';
    } else if (amount <= 0) {
      errors['amount'] = 'Amount must be greater than 0';
    } else if (amount > 1000000) {
      errors['amount'] = 'Amount must be less than 1,000,000';
    }

    // Validar período
    if (period.trim().isEmpty) {
      errors['period'] = 'Period is required';
    } else if (!['weekly', 'monthly', 'yearly', 'custom'].contains(period.toLowerCase())) {
      errors['period'] = 'Invalid period. Must be: weekly, monthly, yearly, or custom';
    }

    // Validar fechas
    if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(startDate)) {
      errors['endDate'] = 'End date must be after start date';
    }

    // Validar que las fechas no estén muy en el pasado
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    if (startDate.isBefore(oneYearAgo)) {
      errors['startDate'] = 'Start date cannot be more than 1 year in the past';
    }

    // Validar que las fechas no estén muy en el futuro
    final twoYearsFromNow = DateTime.now().add(const Duration(days: 730));
    if (endDate.isAfter(twoYearsFromNow)) {
      errors['endDate'] = 'End date cannot be more than 2 years in the future';
    }

    // Validar alert thresholds
    if (alertThresholds != null && alertThresholds.isNotEmpty) {
      for (final threshold in alertThresholds) {
        if (threshold < 0 || threshold > 200) {
          errors['alertThresholds'] = 'Alert thresholds must be between 0 and 200';
          break;
        }
      }

      // Verificar que estén ordenados
      final sorted = List<int>.from(alertThresholds)..sort();
      if (sorted.toString() != alertThresholds.toString()) {
        errors['alertThresholds'] = 'Alert thresholds should be in ascending order';
      }
    }

    final currentState = state;
    final isValid = errors.isEmpty;

    if (currentState is BudgetFormReady) {
      emit(currentState.copyWith(
        errors: errors,
        isValid: isValid,
      ));
    } else {
      emit(BudgetFormReady(
        errors: errors,
        isValid: isValid,
      ));
    }
  }

  /// Envía el formulario para crear un nuevo presupuesto.
  Future<void> submitCreate({
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
    final currentState = state;

    // Validar que el formulario esté listo
    if (currentState is! BudgetFormReady) {
      emit(const BudgetFormError(
        message: 'Form is not ready for submission',
      ));
      return;
    }

    // Verificar validez
    if (!currentState.isValid) {
      emit(BudgetFormError(
        message: 'Please fix validation errors before submitting',
        fieldErrors: currentState.errors,
      ));
      return;
    }

    try {
      emit(const BudgetFormSubmitting());

      final budget = await _budgetService.createBudget(
        name: name,
        category: category,
        amount: amount,
        period: period,
        startDate: startDate,
        endDate: endDate,
        currency: currency ?? 'USD',
        isRecurring: isRecurring ?? false,
        allowRollover: allowRollover ?? false,
        alertThresholds: alertThresholds ?? [50, 75, 90, 100],
        notificationChannels: notificationChannels ?? {
          'push': true,
          'email': false,
          'inApp': true,
        },
      );

      emit(BudgetFormSuccess(
        budget: budget,
        message: 'Budget created successfully',
        isEdit: false,
      ));
    } catch (e) {
      emit(BudgetFormError(
        message: 'Error creating budget: ${e.toString()}',
      ));

      // Volver al estado Ready después de un breve delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (state is BudgetFormError) {
          emit(currentState);
        }
      });
    }
  }

  /// Envía el formulario para actualizar un presupuesto existente.
  Future<void> submitUpdate({
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
    final currentState = state;

    // Validar que el formulario esté listo
    if (currentState is! BudgetFormReady || currentState.existingBudget == null) {
      emit(const BudgetFormError(
        message: 'Form is not ready for update',
      ));
      return;
    }

    // Verificar validez
    if (!currentState.isValid) {
      emit(BudgetFormError(
        message: 'Please fix validation errors before submitting',
        fieldErrors: currentState.errors,
        existingBudget: currentState.existingBudget,
      ));
      return;
    }

    try {
      emit(BudgetFormSubmitting(existingBudget: currentState.existingBudget));

      final budget = await _budgetService.updateBudget(
        budgetId: budgetId,
        name: name,
        category: category,
        amount: amount,
        period: period,
        startDate: startDate,
        endDate: endDate,
        currency: currency,
        isActive: isActive,
        isRecurring: isRecurring,
        allowRollover: allowRollover,
        alertThresholds: alertThresholds,
        notificationChannels: notificationChannels,
      );

      emit(BudgetFormSuccess(
        budget: budget,
        message: 'Budget updated successfully',
        isEdit: true,
      ));
    } catch (e) {
      emit(BudgetFormError(
        message: 'Error updating budget: ${e.toString()}',
        existingBudget: currentState.existingBudget,
      ));

      // Volver al estado Ready después de un breve delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (state is BudgetFormError) {
          emit(currentState);
        }
      });
    }
  }

  /// Restablece el formulario a su estado inicial.
  void reset() {
    emit(const BudgetFormInitial());
  }

  /// Cancela el formulario.
  void cancel() {
    emit(const BudgetFormCancelled());
  }

  /// Limpia los errores del formulario.
  void clearErrors() {
    final currentState = state;
    if (currentState is BudgetFormReady) {
      emit(currentState.copyWith(
        errors: {},
        isValid: true,
      ));
    }
  }

  /// Actualiza un error específico de un campo.
  void setFieldError(String field, String error) {
    final currentState = state;
    if (currentState is BudgetFormReady) {
      final newErrors = Map<String, String>.from(currentState.errors);
      newErrors[field] = error;
      emit(currentState.copyWith(
        errors: newErrors,
        isValid: false,
      ));
    }
  }

  /// Limpia el error de un campo específico.
  void clearFieldError(String field) {
    final currentState = state;
    if (currentState is BudgetFormReady) {
      final newErrors = Map<String, String>.from(currentState.errors);
      newErrors.remove(field);
      emit(currentState.copyWith(
        errors: newErrors,
        isValid: newErrors.isEmpty,
      ));
    }
  }

  /// Genera valores sugeridos para un período específico.
  Map<String, DateTime> getSuggestedDates(String period) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (period.toLowerCase()) {
      case 'weekly':
        // Inicio de la semana actual (lunes)
        startDate = now.subtract(Duration(days: now.weekday - 1));
        endDate = startDate.add(const Duration(days: 6));
        break;

      case 'monthly':
        // Inicio del mes actual
        startDate = DateTime(now.year, now.month, 1);
        // Último día del mes
        endDate = DateTime(now.year, now.month + 1, 0);
        break;

      case 'yearly':
        // Inicio del año actual
        startDate = DateTime(now.year, 1, 1);
        // Fin del año actual
        endDate = DateTime(now.year, 12, 31);
        break;

      default: // custom
        // Hoy y 30 días después
        startDate = now;
        endDate = now.add(const Duration(days: 30));
    }

    // Normalizar a medianoche
    startDate = DateTime(startDate.year, startDate.month, startDate.day);
    endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  /// Genera umbrales de alerta predeterminados según el monto.
  List<int> getDefaultAlertThresholds() {
    return [50, 75, 90, 100];
  }

  /// Genera canales de notificación predeterminados.
  Map<String, bool> getDefaultNotificationChannels() {
    return {
      'push': true,
      'email': false,
      'inApp': true,
    };
  }
}
