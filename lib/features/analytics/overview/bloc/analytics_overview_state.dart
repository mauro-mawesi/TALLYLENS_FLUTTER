import 'package:equatable/equatable.dart';

class AnalyticsOverviewState extends Equatable {
  const AnalyticsOverviewState();
  @override
  List<Object?> get props => [];
}

class AnalyticsOverviewInitial extends AnalyticsOverviewState {}

class AnalyticsOverviewLoading extends AnalyticsOverviewState {}

class AnalyticsOverviewLoaded extends AnalyticsOverviewState {
  final Map<String, dynamic> smartAlerts;
  final Map<String, dynamic> spending;
  final int months;
  const AnalyticsOverviewLoaded({required this.smartAlerts, required this.spending, required this.months});
  @override
  List<Object?> get props => [smartAlerts, spending, months];
}

class AnalyticsOverviewError extends AnalyticsOverviewState {
  final String message;
  const AnalyticsOverviewError(this.message);
  @override
  List<Object?> get props => [message];
}

class AnalyticsOverviewUnauthorized extends AnalyticsOverviewState {}
