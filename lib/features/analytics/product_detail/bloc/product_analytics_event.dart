import 'package:equatable/equatable.dart';

abstract class ProductAnalyticsEvent extends Equatable {
  const ProductAnalyticsEvent();
  @override
  List<Object?> get props => [];
}

class LoadProductAnalytics extends ProductAnalyticsEvent {
  final String productId;
  final int months; // for monthly stats
  final int days; // for price comparison
  const LoadProductAnalytics({required this.productId, this.months = 12, this.days = 90});
  @override
  List<Object?> get props => [productId, months, days];
}

class ChangeMonths extends ProductAnalyticsEvent {
  final int months;
  const ChangeMonths(this.months);
  @override
  List<Object?> get props => [months];
}

class ChangeDays extends ProductAnalyticsEvent {
  final int days;
  const ChangeDays(this.days);
  @override
  List<Object?> get props => [days];
}

