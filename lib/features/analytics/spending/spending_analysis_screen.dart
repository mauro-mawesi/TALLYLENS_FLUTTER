import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/widgets/neon_line_chart.dart';
import 'package:go_router/go_router.dart';
import 'bloc/spending_analytics_bloc.dart';
import 'bloc/spending_analytics_event.dart';
import 'bloc/spending_analytics_state.dart';

class SpendingAnalysisScreen extends StatelessWidget {
  const SpendingAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SpendingAnalyticsBloc(api: sl())..add(const LoadSpending()),
      child: const _SpendingAnalysisView(),
    );
  }
}

class _SpendingAnalysisView extends StatelessWidget {
  const _SpendingAnalysisView();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.spendingAnalysisTitle)),
      body: BlocConsumer<SpendingAnalyticsBloc, SpendingAnalyticsState>(
        listenWhen: (p, c) => c is SpendingAnalyticsUnauthorized,
        listener: (context, state) {
          if (state is SpendingAnalyticsUnauthorized) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.sessionExpired)));
            GoRouter.of(context).go('/unlock');
          }
        },
        builder: (context, state) {
          if (state is SpendingAnalyticsLoading || state is SpendingAnalyticsInitial) {
            return const _SpendingShimmer();
          }
          if (state is SpendingAnalyticsError) {
            return Center(child: Text(t.errorPrefix(state.message)));
          }
          if (state is SpendingAnalyticsLoaded) {
            final data = state.data;
            final months = state.months;
            final categories = (data['categories'] as List?) ?? const [];
            final trends = (data['monthlyTrends'] ?? data['monthly_trends'] ?? const []) as List?;

            // Build totals by month
            final totalsByMonth = <DateTime, double>{};
            for (final e in (trends ?? const [])) {
              final m = DateTime.tryParse((e['month'] ?? '').toString());
              final spent = double.tryParse((e['spent'] ?? '0').toString()) ?? 0.0;
              if (m != null) totalsByMonth[m] = (totalsByMonth[m] ?? 0) + spent;
            }
            final sortedMonths = totalsByMonth.keys.toList()..sort();
            final spots = <FlSpot>[];
            for (int i = 0; i < sortedMonths.length; i++) {
              final m = sortedMonths[i];
              spots.add(FlSpot(i.toDouble(), (totalsByMonth[m] ?? 0.0)));
            }
            final values = spots.map((s) => s.y).toList();
            final minY = values.isEmpty ? 0.0 : (values.reduce((a, b) => a < b ? a : b) * 0.9);
            final maxY = values.isEmpty ? 1.0 : (values.reduce((a, b) => a > b ? a : b) * 1.1);

            return RefreshIndicator(
              onRefresh: () async => context.read<SpendingAnalyticsBloc>().add(LoadSpending(months: months)),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.categoriesTitle,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _RangeChips(
                          selected: months,
                          onSelect: (m) => context.read<SpendingAnalyticsBloc>().add(LoadSpending(months: m)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    borderRadius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 220, child: _Donut(categories: categories)),
                        const SizedBox(height: 8),
                        ...categories.take(6).map((c) => _LegendTile(c: c as Map<String, dynamic>)).toList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(t.monthlyTrendsTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  GlassCard(
                    borderRadius: 20,
                    child: spots.isEmpty
                        ? Padding(padding: const EdgeInsets.all(16), child: Text(t.noData))
                        : SizedBox(
                            height: 180,
                            child: NeonLineChart(
                              points: spots,
                              gradient: const [Color(0xFF8A2BE2), Color(0xFF00E3FF)],
                              minY: minY,
                              maxY: maxY,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _SpendingShimmer extends StatelessWidget {
  const _SpendingShimmer();
  @override
  Widget build(BuildContext context) {
    Color box(BuildContext c) => Theme.of(c).colorScheme.surfaceVariant.withOpacity(0.5);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(height: 18, width: 160, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 12),
        Container(height: 42, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(12))),
        const SizedBox(height: 12),
        Container(height: 260, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 16),
        Container(height: 18, width: 140, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 12),
        Container(height: 200, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(20))),
      ],
    );
  }
}

class _RangeChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _RangeChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final options = [3, 6, 12];
    final labels = {3: t.months3, 6: t.months6, 12: t.months12};
    return Wrap(
      spacing: 8,
      children: options.map((m) {
        final active = m == selected;
        final cs = Theme.of(context).colorScheme;
        return ChoiceChip(
          selected: active,
          label: Text(
            labels[m] ?? '${m}M',
            style: TextStyle(color: active ? cs.onSecondaryContainer : cs.onSurface),
          ),
          onSelected: (_) => onSelect(m),
          backgroundColor: cs.surfaceVariant.withOpacity(0.6),
          selectedColor: cs.secondaryContainer.withOpacity(0.9),
          shape: StadiumBorder(side: BorderSide(color: cs.outline.withOpacity(0.35))),
        );
      }).toList(),
    );
  }
}

class _Donut extends StatelessWidget {
  final List categories;
  const _Donut({required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.noData));
    final total = categories.fold<double>(0.0, (prev, e) => prev + (double.tryParse((e['totalSpent'] ?? '0').toString()) ?? 0));
    final colors = [
      const Color(0xFF8A2BE2),
      const Color(0xFF00E3FF),
      const Color(0xFF00FF7F),
      const Color(0xFFFFC107),
      const Color(0xFFFF6F61),
      const Color(0xFF29B6F6),
    ];
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < categories.length; i++) {
      final c = categories[i] as Map<String, dynamic>;
      final spent = double.tryParse((c['totalSpent'] ?? '0').toString()) ?? 0.0;
      final pct = total == 0 ? 0 : (spent / total) * 100.0;
      sections.add(PieChartSectionData(
        value: spent,
        color: colors[i % colors.length],
        title: pct < 8 ? '' : '${pct.toStringAsFixed(0)}%',
        radius: 70,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ));
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 46,
        sections: sections,
      ),
    );
  }
}

class _LegendTile extends StatelessWidget {
  final Map<String, dynamic> c;
  const _LegendTile({required this.c});

  @override
  Widget build(BuildContext context) {
    final name = (c['category'] ?? '-').toString();
    final pct = double.tryParse((c['percentage'] ?? '0').toString()) ?? 0.0;
    final spent = (c['totalSpent'] ?? 0).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(child: Text('$name • ${pct.toStringAsFixed(0)}%')),
          Text(_formatCurrency(context, spent)),
        ],
      ),
    );
  }
}

String _formatCurrency(BuildContext context, String numberLike) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final fmt = NumberFormat.simpleCurrency(locale: locale);
  final val = double.tryParse(numberLike) ?? 0.0;
  return fmt.format(val);
}
