import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/widgets/neon_line_chart.dart';
import 'bloc/product_analytics_bloc.dart';
import 'bloc/product_analytics_event.dart';
import 'bloc/product_analytics_state.dart';
import 'package:go_router/go_router.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  final String? productName;
  const ProductDetailScreen({super.key, required this.productId, this.productName});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductAnalyticsBloc>()..add(LoadProductAnalytics(productId: productId)),
      child: _ProductDetailView(productName: productName),
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  final String? productName;
  const _ProductDetailView({this.productName});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(productName ?? t.product)),
      body: BlocListener<ProductAnalyticsBloc, ProductAnalyticsState>(
        listenWhen: (prev, curr) => curr is ProductAnalyticsUnauthorized,
        listener: (context, state) {
          if (state is ProductAnalyticsUnauthorized) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.sessionExpired)),
              );
              context.go('/unlock');
            }
          }
        },
        child: BlocBuilder<ProductAnalyticsBloc, ProductAnalyticsState>(
          builder: (context, state) {
            if (state is ProductAnalyticsLoading || state is ProductAnalyticsInitial) {
              return const _ProductShimmer();
            }
            if (state is ProductAnalyticsError) {
              return Center(child: Text(t.errorPrefix(state.message)));
            }
            if (state is ProductAnalyticsLoaded) {
            final product = state.product;
            final months = state.months;
            final days = state.days;

            // Build price trend spots from monthlyStats.avgPrice
            final stats = state.monthlyStats;
            final monthly = <DateTime, double>{};
            for (final e in stats) {
              final m = DateTime.tryParse((e['month'] ?? '').toString());
              final avg = double.tryParse((e['avgPrice'] ?? '0').toString()) ?? 0.0;
              if (m != null) monthly[m] = avg;
            }
            final sortedMonths = monthly.keys.toList()..sort();
            final spots = <FlSpot>[];
            for (int i = 0; i < sortedMonths.length; i++) {
              final m = sortedMonths[i];
              spots.add(FlSpot(i.toDouble(), (monthly[m] ?? 0.0)));
            }
            final values = spots.map((s) => s.y).toList();
            final minY = values.isEmpty ? 0.0 : (values.reduce((a, b) => a < b ? a : b) * 0.95);
            final maxY = values.isEmpty ? 1.0 : (values.reduce((a, b) => a > b ? a : b) * 1.05);
            final localeTag = Localizations.localeOf(context).toLanguageTag();
            String mmm3(DateTime d) {
              final raw = DateFormat.MMM(localeTag).format(d).replaceAll('.', '').trim();
              final base = (raw.length <= 3 ? raw : raw.substring(0, 3)).toUpperCase();
              final yy = (d.year % 100).toString().padLeft(2, '0');
              return '$base $yy';
            }
            final monthLabels = sortedMonths.map((d) => mmm3(d)).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header info
                GlassCard(
                  borderRadius: 20,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.shopping_bag_outlined, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (product?['name'] ?? productName ?? t.product).toString(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product?['category'] != null)
                              Text(
                                (product?['category']).toString(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // Price Trend
                GlassCard(
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.show_chart_rounded, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.monthlyTrendsTitle,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          _MonthsChips(
                            selected: months,
                            onSelect: (m) => context.read<ProductAnalyticsBloc>().add(ChangeMonths(m)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (spots.isEmpty)
                        Text(t.noData)
                      else
                        SizedBox(
                          height: 180,
                          child: NeonLineChart(
                            points: spots,
                            gradient: const [Color(0xFF8A2BE2), Color(0xFF00E3FF)],
                            minY: minY,
                            maxY: maxY,
                            xLabels: monthLabels,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // Price Comparison
                GlassCard(
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.store_mall_directory_outlined, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.priceComparison,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          _DaysChips(
                            selected: days,
                            onSelect: (d) => context.read<ProductAnalyticsBloc>().add(ChangeDays(d)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _PriceComparisonList(merchants: state.priceComparisonMerchants),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // Frequency & Prediction
                GlassCard(
                  borderRadius: 20,
                  child: _FrequencyCard(freq: state.frequency),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    ),
    );
  }
}

class _ProductShimmer extends StatelessWidget {
  const _ProductShimmer();
  @override
  Widget build(BuildContext context) {
    Color box(BuildContext c) => Theme.of(c).colorScheme.surfaceVariant.withOpacity(0.5);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(height: 72, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 16),
        // Monthly price trend
        Container(height: 220, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 16),
        // Price comparison list
        Container(height: 200, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 16),
        // Frequency block
        Container(height: 160, decoration: BoxDecoration(color: box(context), borderRadius: BorderRadius.circular(20))),
      ],
    );
  }
}

class _MonthsChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _MonthsChips({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final options = [3, 6, 12];
    final labels = {3: t.months3, 6: t.months6, 12: t.months12};
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      children: options.map((m) {
        final active = m == selected;
        return ChoiceChip(
          selected: active,
          label: Text(labels[m] ?? '${m}M', style: TextStyle(color: active ? cs.onSecondaryContainer : cs.onSurface)),
          onSelected: (_) => onSelect(m),
          backgroundColor: cs.surfaceVariant.withOpacity(0.6),
          selectedColor: cs.secondaryContainer.withOpacity(0.9),
          shape: StadiumBorder(side: BorderSide(color: cs.outline.withOpacity(0.35))),
        );
      }).toList(),
    );
  }
}

class _DaysChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _DaysChips({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final options = const [30, 60, 90];
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      children: options.map((d) {
        final active = d == selected;
        return ChoiceChip(
          selected: active,
          label: Text('${d}d', style: TextStyle(color: active ? cs.onSecondaryContainer : cs.onSurface)),
          onSelected: (_) => onSelect(d),
          backgroundColor: cs.surfaceVariant.withOpacity(0.6),
          selectedColor: cs.secondaryContainer.withOpacity(0.9),
          shape: StadiumBorder(side: BorderSide(color: cs.outline.withOpacity(0.35))),
        );
      }).toList(),
    );
  }
}

class _PriceComparisonList extends StatelessWidget {
  final List<dynamic> merchants;
  const _PriceComparisonList({required this.merchants});
  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) return Text(AppLocalizations.of(context)!.noData);
    final sorted = [...merchants]..sort((a, b) => ((a['avgPrice'] ?? 0).toDouble()).compareTo((b['avgPrice'] ?? 0).toDouble()));
    final minPrice = (sorted.first['avgPrice'] ?? 0).toDouble();
    final maxPrice = (sorted.last['avgPrice'] ?? minPrice).toDouble();
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = NumberFormat.simpleCurrency(locale: locale);
    return Column(
      children: sorted.map((m) {
        final name = (m['name'] ?? '-').toString();
        final avg = (m['avgPrice'] ?? 0).toDouble();
        final isBest = (m['isBestPrice'] ?? false) == true || avg == minPrice;
        final rel = maxPrice == minPrice ? 1.0 : ((avg - minPrice) / (maxPrice - minPrice)).clamp(0, 1);
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
                        Text(fmt.format(avg)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: 1.0 - rel,
                        minHeight: 8,
                        backgroundColor: cs.surfaceVariant.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation(isBest ? const Color(0xFF00FF7F) : cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              if (isBest)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.emoji_events_outlined, color: cs.secondary),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FrequencyCard extends StatelessWidget {
  final Map<String, dynamic>? freq;
  const _FrequencyCard({required this.freq});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final f = freq ?? const {};
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String fmtDate(String? s) {
      if (s == null || s.isEmpty) return t.valueDash;
      final d = DateTime.tryParse(s);
      if (d == null) return t.valueDash;
      return DateFormat.yMMMd(locale).format(d.toLocal());
    }
    final urgency = (f['urgencyLevel'] ?? 'low').toString();
    Color badge() => urgency == 'high'
        ? Colors.redAccent
        : (urgency == 'medium' ? Colors.amber : const Color(0xFF00FF7F));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_outlined, color: cs.primary),
            const SizedBox(width: 8),
            Text(t.frequencyAndPrediction, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: badge().withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
              child: Text(urgency.toUpperCase(), style: TextStyle(color: badge(), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _KV(label: t.avgDaysBetween, value: (f['avgDaysBetween'] ?? t.valueDash).toString()),
        _KV(label: t.lastPurchase, value: fmtDate(f['lastPurchase']?.toString())),
        _KV(label: t.daysSinceLast, value: (f['daysSinceLastPurchase'] ?? t.valueDash).toString()),
        _KV(label: t.nextPurchasePrediction, value: fmtDate(f['nextPurchasePrediction']?.toString())),
      ],
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  const _KV({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
