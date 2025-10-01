import 'package:equatable/equatable.dart';

class ProductAnalyticsState extends Equatable {
  const ProductAnalyticsState();
  @override
  List<Object?> get props => [];
}

class ProductAnalyticsInitial extends ProductAnalyticsState {}

class ProductAnalyticsLoading extends ProductAnalyticsState {}

class ProductAnalyticsLoaded extends ProductAnalyticsState {
  final Map<String, dynamic>? product; // from monthly stats / frequency
  final List<dynamic> monthlyStats; // list of maps
  final List<dynamic> priceComparisonMerchants; // list of merchants maps
  final Map<String, dynamic>? frequency; // frequency map
  final int months;
  final int days;
  const ProductAnalyticsLoaded({
    required this.product,
    required this.monthlyStats,
    required this.priceComparisonMerchants,
    required this.frequency,
    required this.months,
    required this.days,
  });
  @override
  List<Object?> get props => [product ?? {}, monthlyStats, priceComparisonMerchants, frequency ?? {}, months, days];
}

class ProductAnalyticsError extends ProductAnalyticsState {
  final String message;
  const ProductAnalyticsError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProductAnalyticsUnauthorized extends ProductAnalyticsState {}
