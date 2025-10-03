import 'package:flutter_bloc/flutter_bloc.dart';
import 'monthly_bubbles_state.dart';
import 'package:recibos_flutter/core/services/api_service.dart';

class MonthlyBubblesCubit extends Cubit<MonthlyBubblesState> {
  final ApiService api;
  MonthlyBubblesCubit({required this.api}) : super(MonthlyBubblesLoading());

  Future<void> load({int months = 4}) async {
    emit(MonthlyBubblesLoading());
    try {
      // Preferir endpoint dedicado de totales mensuales
      List<Map<String, dynamic>> monthlyTotals = [];
      try {
        monthlyTotals = await api.getMonthlyTotals(months: months);
      } catch (_) {
        // Fallback: sumar por mes a partir de spending-analysis (agrega categorías)
      }

      List? raw;
      if (monthlyTotals.isEmpty) {
        final res = await api.getSpendingAnalysis(months: months);
        raw = (res['monthlyTrends'] ?? res['monthly_trends'] ?? []) as List?;
      }

      // Construir últimos N meses exactos desde hoy (incluyendo mes actual)
      final now = DateTime.now();
      final targetMonths = List.generate(months, (i) {
        final d = DateTime(now.year, now.month - (months - 1 - i), 1);
        return DateTime(d.year, d.month, 1);
      });

      // Mapear respuesta API a mapa { yyyy-mm-01: spent }
      final map = <String, double>{};
      if (monthlyTotals.isNotEmpty) {
        for (final e in monthlyTotals) {
          final monthStr = (e['month'] ?? '').toString();
          final spent = double.tryParse((e['totalSpent'] ?? '0').toString()) ?? 0.0;
          final dt = DateTime.tryParse(monthStr);
          if (dt != null) {
            final key = DateTime(dt.year, dt.month, 1).toIso8601String();
            map[key] = (map[key] ?? 0) + spent;
          }
        }
      } else if (raw != null) {
        for (final e in raw) {
          if (e is Map) {
            final monthStr = (e['month'] ?? '').toString();
            final spent = double.tryParse((e['spent'] ?? '0').toString()) ?? 0.0;
            final dt = DateTime.tryParse(monthStr);
            if (dt != null) {
              final key = DateTime(dt.year, dt.month, 1).toIso8601String();
              map[key] = (map[key] ?? 0) + spent; // suma categorías del mismo mes
            }
          }
        }
      }

      final points = <MonthlyPoint>[];
      for (final m in targetMonths) {
        final key = DateTime(m.year, m.month, 1).toIso8601String();
        final v = map[key] ?? 0.0; // rellena con 0 si falta
        points.add(MonthlyPoint(month: m, value: v));
      }

      if (points.every((p) => p.value == 0)) {
        emit(MonthlyBubblesEmpty());
      } else {
        emit(MonthlyBubblesLoaded(points));
      }
    } catch (e) {
      emit(MonthlyBubblesError(e.toString()));
    }
  }
}
