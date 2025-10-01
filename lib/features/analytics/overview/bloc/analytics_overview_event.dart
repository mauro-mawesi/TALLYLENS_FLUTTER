import 'package:equatable/equatable.dart';

abstract class AnalyticsOverviewEvent extends Equatable {
  const AnalyticsOverviewEvent();
  @override
  List<Object?> get props => [];
}

class LoadOverview extends AnalyticsOverviewEvent {
  final int months;
  const LoadOverview({this.months = 6});
  @override
  List<Object?> get props => [months];
}

