import 'package:equatable/equatable.dart';

class MonthlyPoint extends Equatable {
  final DateTime month;
  final double value;
  const MonthlyPoint({required this.month, required this.value});

  @override
  List<Object?> get props => [month, value];
}

abstract class MonthlyBubblesState extends Equatable {
  const MonthlyBubblesState();
  @override
  List<Object?> get props => [];
}

class MonthlyBubblesLoading extends MonthlyBubblesState {}

class MonthlyBubblesLoaded extends MonthlyBubblesState {
  final List<MonthlyPoint> points; // max 4
  const MonthlyBubblesLoaded(this.points);
  @override
  List<Object?> get props => [points];
}

class MonthlyBubblesEmpty extends MonthlyBubblesState {}

class MonthlyBubblesError extends MonthlyBubblesState {
  final String message;
  const MonthlyBubblesError(this.message);
  @override
  List<Object?> get props => [message];
}

