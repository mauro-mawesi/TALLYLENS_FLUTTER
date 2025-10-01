import 'package:equatable/equatable.dart';

abstract class SpendingAnalyticsEvent extends Equatable {
  const SpendingAnalyticsEvent();
  @override
  List<Object?> get props => [];
}

class LoadSpending extends SpendingAnalyticsEvent {
  final int months;
  const LoadSpending({this.months = 6});
  @override
  List<Object?> get props => [months];
}

