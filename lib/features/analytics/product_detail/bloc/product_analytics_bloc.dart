import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'product_analytics_event.dart';
import 'product_analytics_state.dart';
import 'package:recibos_flutter/core/services/errors.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';

class ProductAnalyticsBloc extends Bloc<ProductAnalyticsEvent, ProductAnalyticsState> {
  final ApiService api;
  String? _productId;
  int _months = 12;
  int _days = 90;

  ProductAnalyticsBloc({required this.api}) : super(ProductAnalyticsInitial()) {
    on<LoadProductAnalytics>(_onLoad);
    on<ChangeMonths>(_onChangeMonths);
    on<ChangeDays>(_onChangeDays);
  }

  Future<void> _onLoad(LoadProductAnalytics event, Emitter<ProductAnalyticsState> emit) async {
    try {
      emit(ProductAnalyticsLoading());
      _productId = event.productId;
      _months = event.months;
      _days = event.days;
      final monthly = await api.getProductMonthlyStats(event.productId, months: event.months);
      final price = await api.getProductPriceComparison(event.productId, days: event.days);
      final freq = await api.getProductFrequencyAnalysis(event.productId);
      final product = monthly['product'] as Map<String, dynamic>? ?? freq['product'] as Map<String, dynamic>?;
      final monthlyStats = (monthly['monthlyStats'] as List?) ?? const [];
      final merchants = (price['merchants'] as List?) ?? const [];
      final frequency = freq['frequency'] as Map<String, dynamic>?;
      emit(ProductAnalyticsLoaded(
        product: product,
        monthlyStats: monthlyStats,
        priceComparisonMerchants: merchants,
        frequency: frequency,
        months: _months,
        days: _days,
      ));
    } catch (e) {
      if (e is UnauthorizedException) {
        sl<AuthService>().forceLock();
        emit(ProductAnalyticsUnauthorized());
      } else {
        emit(ProductAnalyticsError(e.toString()));
      }
    }
  }

  Future<void> _onChangeMonths(ChangeMonths event, Emitter<ProductAnalyticsState> emit) async {
    final current = state;
    if (_productId == null) return;
    _months = event.months;
    if (current is ProductAnalyticsLoaded) {
      emit(ProductAnalyticsLoaded(
        product: current.product,
        monthlyStats: current.monthlyStats,
        priceComparisonMerchants: current.priceComparisonMerchants,
        frequency: current.frequency,
        months: _months,
        days: _days,
      ));
    }
    try {
      final monthly = await api.getProductMonthlyStats(_productId!, months: _months);
      final product = monthly['product'] as Map<String, dynamic>?;
      final stats = (monthly['monthlyStats'] as List?) ?? const [];
      final base = state is ProductAnalyticsLoaded ? state as ProductAnalyticsLoaded : null;
      emit(ProductAnalyticsLoaded(
        product: product ?? base?.product,
        monthlyStats: stats,
        priceComparisonMerchants: base?.priceComparisonMerchants ?? const [],
        frequency: base?.frequency,
        months: _months,
        days: _days,
      ));
    } catch (e) {
      if (e is UnauthorizedException) {
        sl<AuthService>().forceLock();
        emit(ProductAnalyticsUnauthorized());
      }
    }
  }

  Future<void> _onChangeDays(ChangeDays event, Emitter<ProductAnalyticsState> emit) async {
    final current = state;
    if (_productId == null) return;
    _days = event.days;
    if (current is ProductAnalyticsLoaded) {
      emit(ProductAnalyticsLoaded(
        product: current.product,
        monthlyStats: current.monthlyStats,
        priceComparisonMerchants: current.priceComparisonMerchants,
        frequency: current.frequency,
        months: _months,
        days: _days,
      ));
    }
    try {
      final pr = await api.getProductPriceComparison(_productId!, days: _days);
      final merchants = (pr['merchants'] as List?) ?? const [];
      final base = state is ProductAnalyticsLoaded ? state as ProductAnalyticsLoaded : null;
      emit(ProductAnalyticsLoaded(
        product: base?.product,
        monthlyStats: base?.monthlyStats ?? const [],
        priceComparisonMerchants: merchants,
        frequency: base?.frequency,
        months: _months,
        days: _days,
      ));
    } catch (e) {
      if (e is UnauthorizedException) {
        sl<AuthService>().forceLock();
        emit(ProductAnalyticsUnauthorized());
      }
    }
  }
}
