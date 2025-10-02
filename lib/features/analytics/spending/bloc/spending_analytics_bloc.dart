import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'spending_analytics_event.dart';
import 'spending_analytics_state.dart';
import 'package:recibos_flutter/core/services/errors.dart';

class SpendingAnalyticsBloc extends Bloc<SpendingAnalyticsEvent, SpendingAnalyticsState> {
  final ApiService api;
  SpendingAnalyticsBloc({required this.api}) : super(SpendingAnalyticsInitial()) {
    on<LoadSpending>(_onLoad);
  }

  Future<void> _onLoad(LoadSpending event, Emitter<SpendingAnalyticsState> emit) async {
    try {
      emit(SpendingAnalyticsLoading());
      final data = await api.getSpendingAnalysis(months: event.months);
      emit(SpendingAnalyticsLoaded(data: data, months: event.months));
    } catch (e) {
      if (e is UnauthorizedException) {
        emit(SpendingAnalyticsUnauthorized());
      } else {
        emit(SpendingAnalyticsError(e.toString()));
      }
    }
  }
}
