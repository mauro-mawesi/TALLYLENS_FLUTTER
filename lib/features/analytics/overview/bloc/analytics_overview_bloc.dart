import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'analytics_overview_event.dart';
import 'analytics_overview_state.dart';

class AnalyticsOverviewBloc extends Bloc<AnalyticsOverviewEvent, AnalyticsOverviewState> {
  final ApiService api;
  AnalyticsOverviewBloc({required this.api}) : super(AnalyticsOverviewInitial()) {
    on<LoadOverview>(_onLoad);
  }

  Future<void> _onLoad(LoadOverview event, Emitter<AnalyticsOverviewState> emit) async {
    try {
      emit(AnalyticsOverviewLoading());
      final alerts = await api.getSmartAlerts();
      final spending = await api.getSpendingAnalysis(months: event.months);
      emit(AnalyticsOverviewLoaded(smartAlerts: alerts, spending: spending, months: event.months));
    } catch (e) {
      emit(AnalyticsOverviewError(e.toString()));
    }
  }
}

