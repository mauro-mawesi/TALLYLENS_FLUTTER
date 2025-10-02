import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/widgets/neon_line_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'bloc/analytics_overview_bloc.dart';
import 'bloc/analytics_overview_event.dart';
import 'bloc/analytics_overview_state.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:go_router/go_router.dart';

class AnalyticsOverviewScreen extends StatelessWidget {
  const AnalyticsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AnalyticsOverviewBloc(api: sl())..add(const LoadOverview()),
      child: const _AnalyticsOverviewView(),
    );
  }
}

class _AnalyticsOverviewView extends StatelessWidget {
  const _AnalyticsOverviewView();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final name = sl<AuthService>().displayName ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(t.greeting(name))),
      body: BlocConsumer<AnalyticsOverviewBloc, AnalyticsOverviewState>(
        listenWhen: (p, c) => c is AnalyticsOverviewUnauthorized,
        listener: (context, state) {
          if (state is AnalyticsOverviewUnauthorized) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.sessionExpired)),
            );
            context.go('/unlock');
          }
        },
        builder: (context, state) {
          if (state is AnalyticsOverviewLoading || state is AnalyticsOverviewInitial) {
            return const _OverviewShimmer();
          }
          if (state is AnalyticsOverviewError) {
            return Center(child: Text(t.errorPrefix(state.message)));
          }
          if (state is AnalyticsOverviewLoaded) {
            final alerts = (state.smartAlerts['alerts'] as List?) ?? const [];
            final alertCount = (state.smartAlerts['alertCount'] as int?) ?? alerts.length;
            final spendingCategories = (state.spending['categories'] as List?) ?? const [];
            final monthlyTrends = (state.spending['monthlyTrends'] ?? state.spending['monthly_trends'] ?? const []) as List?;
            final months = state.months;
            // Agregar tendencia total por mes sumando categorías
            final totalsByMonth = <DateTime, double>{};
            for (final e in (monthlyTrends ?? const [])) {
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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Smart Alerts
                GlassCard(
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt_outlined, color: cs.secondary),
                          const SizedBox(width: 8),
                          Text(t.smartAlerts, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (alertCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('$alertCount'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (alerts.isEmpty)
                        Text(t.noAlerts)
                      else
                        Column(
                          children: alerts.take(3).map((a) {
                            final map = a as Map<String, dynamic>;
                            final title = (map['title'] ?? '').toString();
                            final message = (map['message'] ?? '').toString();
                            final sev = (map['severity'] ?? 'low').toString();
                            final color = sev == 'high'
                                ? Colors.redAccent
                                : sev == 'medium'
                                    ? Colors.amberAccent
                                    : cs.secondary; // green
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(Icons.warning_amber_rounded, color: color)),
                              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Spending Snapshot
                GlassCard(
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pie_chart_outline, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            t.spendingSnapshot,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => GoRouter.of(context).push('/analytics/spending'),
                            child: Text(t.seeAll),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _RangeChips(
                          selected: months,
                          onSelect: (m) => context.read<AnalyticsOverviewBloc>().add(LoadOverview(months: m)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Trend line (Revolut-like)
                      if (spots.isNotEmpty)
                        SizedBox(
                          height: 160,
                          child: NeonLineChart(
                            points: spots,
                            gradient: const [Color(0xFF8A2BE2), Color(0xFF00E3FF)],
                            minY: minY,
                            maxY: maxY,
                          ),
                        )
                      else
                        Text(t.noData),
                      const SizedBox(height: 12),
                      // Total spent badge
                      if (state.spending['totalSpent'] != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                            child: Text(_formatCurrency(context, (state.spending['totalSpent']).toString())),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (spendingCategories.isEmpty)
                        Text(t.noData)
                      else ...[
                        for (final c in spendingCategories.take(3)) _CategoryTile(data: c as Map<String, dynamic>),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _OverviewShimmer extends StatelessWidget {
  const _OverviewShimmer();
  @override
  Widget build(BuildContext context) {
    Color box(BuildContext c) => Theme.of(c).colorScheme.surfaceVariant.withOpacity(0.5);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(height: 140, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 16),
        Container(height: 220, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(20))),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CategoryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = (data['category'] ?? '-').toString();
    final pct = double.tryParse((data['percentage'] ?? '0').toString()) ?? 0.0;
    final spent = (data['totalSpent'] ?? 0).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text('${pct.toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0, 1),
                    backgroundColor: cs.surfaceVariant.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00FF7F)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('\$' + spent.toString()),
        ],
      ),
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
    final labels = {
      3: t.months3,
      6: t.months6,
      12: t.months12,
    };
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

String _formatCurrency(BuildContext context, String numberLike) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final fmt = NumberFormat.simpleCurrency(locale: locale);
  final val = double.tryParse(numberLike) ?? 0.0;
  return fmt.format(val);
}
