import 'package:equatable/equatable.dart';

class SpendingAnalyticsState extends Equatable {
  const SpendingAnalyticsState();
  @override
  List<Object?> get props => [];
}

class SpendingAnalyticsInitial extends SpendingAnalyticsState {}

class SpendingAnalyticsLoading extends SpendingAnalyticsState {}

class SpendingAnalyticsLoaded extends SpendingAnalyticsState {
  final Map<String, dynamic> data;
  final int months;
  const SpendingAnalyticsLoaded({required this.data, required this.months});
  @override
  List<Object?> get props => [data, months];
}

class SpendingAnalyticsError extends SpendingAnalyticsState {
  final String message;
  const SpendingAnalyticsError(this.message);
  @override
  List<Object?> get props => [message];
}

