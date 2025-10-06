import 'package:equatable/equatable.dart';
import 'package:recibos_flutter/core/models/budget.dart';

/// Clase base abstracta para todos los estados del BudgetFormCubit.
abstract class BudgetFormState extends Equatable {
  const BudgetFormState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial del formulario (nuevo presupuesto).
class BudgetFormInitial extends BudgetFormState {
  const BudgetFormInitial();
}

/// Estado cuando se está cargando un presupuesto existente para editar.
class BudgetFormLoading extends BudgetFormState {
  const BudgetFormLoading();
}

/// Estado cuando el formulario está listo para editar/crear.
class BudgetFormReady extends BudgetFormState {
  final Budget? existingBudget; // null si es nuevo presupuesto
  final Map<String, String> errors;
  final bool isValid;

  const BudgetFormReady({
    this.existingBudget,
    this.errors = const {},
    this.isValid = false,
  });

  /// Crea una copia del estado con los valores actualizados.
  BudgetFormReady copyWith({
    Budget? existingBudget,
    Map<String, String>? errors,
    bool? isValid,
    bool clearExistingBudget = false,
  }) {
    return BudgetFormReady(
      existingBudget: clearExistingBudget ? null : (existingBudget ?? this.existingBudget),
      errors: errors ?? this.errors,
      isValid: isValid ?? this.isValid,
    );
  }

  /// Verifica si es un formulario de edición.
  bool get isEditing => existingBudget != null;

  /// Verifica si hay errores.
  bool get hasErrors => errors.isNotEmpty;

  @override
  List<Object?> get props => [existingBudget, errors, isValid];
}

/// Estado mientras se está enviando el formulario.
class BudgetFormSubmitting extends BudgetFormState {
  final Budget? existingBudget;

  const BudgetFormSubmitting({this.existingBudget});

  @override
  List<Object?> get props => [existingBudget];
}

/// Estado cuando el formulario se envió con éxito.
class BudgetFormSuccess extends BudgetFormState {
  final Budget budget;
  final String message;
  final bool isEdit;

  const BudgetFormSuccess({
    required this.budget,
    required this.message,
    required this.isEdit,
  });

  @override
  List<Object> get props => [budget, message, isEdit];
}

/// Estado cuando ocurrió un error al enviar el formulario.
class BudgetFormError extends BudgetFormState {
  final String message;
  final Map<String, String> fieldErrors;
  final Budget? existingBudget;

  const BudgetFormError({
    required this.message,
    this.fieldErrors = const {},
    this.existingBudget,
  });

  @override
  List<Object?> get props => [message, fieldErrors, existingBudget];
}

/// Estado cuando se solicitó cancelar el formulario.
class BudgetFormCancelled extends BudgetFormState {
  const BudgetFormCancelled();
}
