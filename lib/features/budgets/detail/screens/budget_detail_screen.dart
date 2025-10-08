import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/models/budget.dart';
import 'package:recibos_flutter/features/budgets/detail/bloc/budget_detail_bloc.dart';
import 'package:recibos_flutter/features/budgets/detail/bloc/budget_detail_event.dart';
import 'package:recibos_flutter/features/budgets/detail/bloc/budget_detail_state.dart';
import 'package:recibos_flutter/features/budgets/widgets/widgets.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/services/budget_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';

/// Pantalla de detalles de un presupuesto específico.
/// Muestra progreso detallado, predicciones, insights y alertas.
class BudgetDetailScreen extends StatelessWidget {
  final String budgetId;

  const BudgetDetailScreen({
    super.key,
    required this.budgetId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BudgetDetailBloc>()..add(FetchBudgetDetail(budgetId)),
      child: const _BudgetDetailView(),
    );
  }
}

class _BudgetDetailView extends StatelessWidget {
  const _BudgetDetailView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<BudgetDetailBloc, BudgetDetailState>(
      builder: (context, state) {
        if (state is BudgetDetailLoading) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n?.budgetDetailsTitle ?? 'Budget Details')),
            body: BudgetLoadingState(message: l10n?.budgetDetailsLoading ?? 'Loading budget details...'),
          );
        }

        if (state is BudgetDetailError) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n?.budgetDetailsTitle ?? 'Budget Details')),
            body: BudgetErrorState(
              message: state.message,
              onRetry: () {
                final bloc = context.read<BudgetDetailBloc>();
                // Use Refresh event; bloc tracks current budget id internally
                bloc.add(const RefreshBudgetDetail());
              },
            ),
          );
        }

        if (state is BudgetDetailLoaded) {
          return _BudgetDetailContent(state: state);
        }

        return Scaffold(
          appBar: AppBar(title: Text(l10n?.budgetDetailsTitle ?? 'Budget Details')),
          body: const Center(child: Text('Unknown state')),
        );
      },
    );
  }
}

class _BudgetDetailContent extends StatelessWidget {
  final BudgetDetailLoaded state;

  const _BudgetDetailContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final budget = state.budget;
    final progress = state.progress;
    final theme = Theme.of(context);

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(budget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await context.push('/budgets/${budget.id}/edit');
              // Refresh budget details after editing
              if (context.mounted) {
                context.read<BudgetDetailBloc>().add(FetchBudgetDetail(budget.id));
              }
            },
            tooltip: l10n?.budgetEditTooltip ?? 'Edit budget',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'insights',
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline),
                    const SizedBox(width: 8),
                    Text(l10n?.budgetMenuViewInsights ?? 'View Insights'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    const Icon(Icons.copy),
                    const SizedBox(width: 8),
                    Text(l10n?.budgetMenuDuplicate ?? 'Duplicate'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(l10n?.budgetMenuDelete ?? 'Delete', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) => _handleMenuAction(context, value as String, budget),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<BudgetDetailBloc>().add(const RefreshBudgetDetail());
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress card
              if (progress != null)
                BudgetProgressCard(
                  budget: budget,
                  progress: progress,
                  showDetails: true,
                ),

              // Date range info
              _DateRangeCard(budget: budget),

              // Spending chart
              if (progress != null) _SpendingChartCard(
                budget: budget,
                progress: progress,
                spendingTrend: state.spendingTrend,
              ),

              // Predictions
              if (state.predictions != null && state.predictions!.isNotEmpty)
                _PredictionsCard(predictions: state.predictions!),

              // Insights
              if (state.insights != null && state.insights!.isNotEmpty)
                _InsightsCard(insights: state.insights!),

              // Alerts
              if (state.alerts != null && state.alerts!.isNotEmpty)
                _AlertsCard(alerts: state.alerts!),

              // Settings
              _BudgetSettingsCard(budget: budget),
            ],
          ),
        ),
      ),
      floatingActionButton: budget.isCurrentlyActive
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _toggleBudgetStatus(context, budget),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n?.budgetActivateCta ?? 'Activate'),
            ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, Budget budget) {
    switch (action) {
      case 'insights':
        context.push('/budgets/${budget.id}/insights');
        break;
      case 'duplicate':
        _showDuplicateDialog(context, budget);
        break;
      case 'delete':
        _showDeleteDialog(context, budget);
        break;
    }
  }

  void _showDuplicateDialog(BuildContext context, Budget budget) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.budgetDuplicateTitle ?? 'Duplicate Budget'),
        content: Text(l10n?.budgetDuplicateMessage ?? 'This will create a copy of this budget with new dates. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final svc = sl<BudgetService>();
                final newBudget = await svc.duplicateBudget(
                  budgetId: budget.id,
                  startDate: budget.startDate,
                  endDate: budget.endDate,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n?.budgetDuplicateSuccess ?? 'Budget duplicated successfully')),
                  );
                  context.push('/budgets/${newBudget.id}');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n?.budgetDuplicateError ?? 'Error duplicating budget')),
                  );
                }
              }
            },
            child: Text(l10n?.budgetMenuDuplicate ?? 'Duplicate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Budget budget) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.budgetDeleteTitle ?? 'Delete Budget'),
        content: Text(l10n?.budgetDeleteMessage ?? 'Are you sure you want to delete this budget? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final svc = sl<BudgetService>();
                await svc.deleteBudget(budget.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n?.budgetDeleteSuccess ?? 'Budget deleted successfully')),
                  );
                  // Exit detail screen after deletion
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n?.budgetDeleteError ?? 'Error deleting budget')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n?.budgetMenuDelete ?? 'Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleBudgetStatus(BuildContext context, Budget budget) {
    context.read<BudgetDetailBloc>().add(
          ToggleBudgetStatus(
            budgetId: budget.id,
            isActive: !budget.isActive,
          ),
        );
  }
}

class _DateRangeCard extends StatelessWidget {
  final Budget budget;

  const _DateRangeCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        borderRadius: 20,
        color: FlowColors.glassTint(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Period',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateItem(
                    icon: Icons.calendar_today,
                    label: 'Start Date',
                    value: dateFormat.format(budget.startDate),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DateItem(
                    icon: Icons.event,
                    label: 'End Date',
                    value: dateFormat.format(budget.endDate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${budget.daysRemaining} days remaining',
                  style: theme.textTheme.bodyMedium,
                ),
                Chip(
                  label: Text(budget.period.toUpperCase()),
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DateItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SpendingChartCard extends StatelessWidget {
  final Budget budget;
  final BudgetProgress progress;
  final Map<String, dynamic>? spendingTrend;

  const _SpendingChartCard({
    required this.budget,
    required this.progress,
    this.spendingTrend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Preferimos serie acumulada del mes actual con puntos solo en días con recibos
    final currentMonth = spendingTrend != null
        ? spendingTrend!['currentMonth'] as Map<String, dynamic>?
        : null;
    final dailyPoints = currentMonth != null
        ? (currentMonth['dailyPoints'] as List<dynamic>?)
        : null;

    if (dailyPoints != null && dailyPoints.isNotEmpty) {
      final chartData = _generateChartDataFromCurrentMonth(dailyPoints);

      // Proyección al final de mes (basada en histórico de 6 meses + MTD)
      final projection = (spendingTrend?['projection'] as Map<String, dynamic>?) ?? {};
      final projectedTotal = projection['projectedTotal'] as num?;

      // Determinar día final del mes para ubicar la proyección en el eje X
      final monthStr = (currentMonth?['month'] as String?) ?? DateFormat('yyyy-MM').format(DateTime.now());
      final parts = monthStr.split('-');
      final year = int.tryParse(parts[0]) ?? DateTime.now().year;
      final month = int.tryParse(parts[1]) ?? DateTime.now().month;
      final daysInMonth = DateTime(year, month + 1, 0).day;

      // Ajuste de escala Y para no cortar proyección ni presupuesto
      final candidates = <double>[budget.amount * 1.3, ...chartData.map((p) => p.value)];
      if (projectedTotal != null) {
        candidates.add(projectedTotal.toDouble() * 1.15);
      }
      final maxY = candidates.reduce((a, b) => a > b ? a : b);

      return BudgetChart(
        data: chartData,
        type: ChartType.line,
        title: l10n?.budgetChartSpendingTrend ?? 'Spending Trend',
        subtitle: l10n?.budgetChartSpendingTrendSubtitle ?? 'Month-to-date cumulative & projection',
        currency: budget.currency,
        maxY: maxY,
        budgetAmount: budget.amount,
        currentSpending: progress.currentSpending,
        projectedAmount: projectedTotal?.toDouble(),
        showBudgetLine: true,
        showProjection: projectedTotal != null,
        projectionX: daysInMonth.toDouble(),
        xMax: daysInMonth.toDouble(),
      );
    }

    // Fallback: si no hay dailyPoints, intentar mostrar histórico mensual para no “ocultar” la gráfica
    final historical = spendingTrend != null
        ? (spendingTrend!['historicalData'] as List<dynamic>?)
        : null;
    if (historical != null && historical.isNotEmpty) {
      final chartData = _generateChartDataFromHistorical(historical);
      final maxY = [
        budget.amount * 1.3,
        ...chartData.map((p) => p.value),
      ].reduce((a, b) => a > b ? a : b);

      return BudgetChart(
        data: chartData,
        type: ChartType.line,
        title: l10n?.budgetChartSpendingTrend ?? 'Spending Trend',
        subtitle: l10n?.budgetChartSpendingTrendSubtitle ?? 'Monthly totals (historical)',
        currency: budget.currency,
        maxY: maxY,
        budgetAmount: budget.amount,
        currentSpending: progress.currentSpending,
        // En histórico no mostramos proyección
        showBudgetLine: true,
        showProjection: false,
      );
    }

    return const SizedBox.shrink();
  }

  // Convierte dailyPoints (solo días con recibos) a puntos acumulados por día del mes
  List<ChartDataPoint> _generateChartDataFromCurrentMonth(List<dynamic> dailyPoints) {
    return dailyPoints.map((item) {
      final data = item as Map<String, dynamic>;
      final dateStr = data['date'] as String; // YYYY-MM-DD
      final cumulative = (data['cumulative'] as num).toDouble();
      final dayInt = DateTime.parse(dateStr).day;
      return ChartDataPoint(label: dayInt.toString(), value: cumulative, x: dayInt.toDouble());
    }).toList();
  }

  // Fallback: construir datos a partir de histórico mensual
  List<ChartDataPoint> _generateChartDataFromHistorical(List<dynamic> historicalData) {
    return historicalData.map((item) {
      final data = item as Map<String, dynamic>;
      final month = data['month'] as String; // YYYY-MM
      final total = (data['total'] as num).toDouble();
      final parts = month.split('-');
      final monthNum = int.tryParse(parts[1]) ?? 1;
      const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final label = monthNum >= 1 && monthNum <= 12 ? monthNames[monthNum - 1] : month;
      return ChartDataPoint(label: label, value: total);
    }).toList();
  }
}

class _PredictionsCard extends StatelessWidget {
  final Map<String, dynamic> predictions;

  const _PredictionsCard({required this.predictions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final willExceed = predictions['willExceed'] ?? false;
    final projectedSpending = (predictions['projectedSpending'] ?? 0.0) as num;
    final confidence = predictions['confidence'] ?? 50;

    if (!isDark) {
      final t = AppLocalizations.of(context);
      final projectedText = t != null
          ? t.budgetPredictionProjectedSpending(projectedSpending.toStringAsFixed(2))
          : 'Projected spending: ${projectedSpending.toStringAsFixed(2)}';
      // Light theme: keep current clean style
      return Padding(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          borderRadius: 20,
          color: willExceed
              ? theme.colorScheme.errorContainer.withOpacity(0.3)
              : theme.colorScheme.primaryContainer.withOpacity(0.3),
          padding: const EdgeInsets.all(16),
          child: _PredictionContent(
            title: t?.budgetPredictionTitle ?? 'Prediction',
            onTrackText: t?.budgetPredictionOnTrack ?? "You're on track to stay within budget",
            willExceedText: t?.budgetPredictionWillExceed ?? "You're likely to exceed your budget",
            projectedLabel: projectedText,
            titleStyle: theme.textTheme.titleMedium,
            textStyle: theme.textTheme.bodyMedium,
            subTextStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            willExceed: willExceed,
            projectedSpending: projectedSpending.toDouble(),
            confidence: confidence,
          ),
        ),
      );
    }

    // Dark theme palettes (conditional)
    // Exceed likely => crimson palette; On-track => cyan/purple palette
    final Color crimson = const Color(0xFFB71C1C); // deep red
    final Color softRed = const Color(0xFFE57373);
    final Color neonCyan = const Color(0xFF00E3FF);
    final Color neonPurple = const Color(0xFF8A2BE2);

    final bool exceed = willExceed == true;
    final Color borderColor = exceed ? crimson.withOpacity(0.7) : neonCyan.withOpacity(0.6);
    final Color glow1 = exceed ? crimson.withOpacity(0.22) : neonCyan.withOpacity(0.20);
    final Color glow2 = exceed ? softRed.withOpacity(0.18) : neonPurple.withOpacity(0.16);
    final Color cardBg = exceed
        ? crimson.withOpacity(0.14)
        : const Color(0xFF0D1B2A).withOpacity(0.35); // cool dark with cyan tint
    final List<Color> iconGradient = exceed
        ? [crimson, softRed]
        : [neonPurple, neonCyan];
    final Color accent = exceed ? crimson : neonCyan;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(color: glow1, blurRadius: 16, spreadRadius: 1, offset: const Offset(0, 6)),
            BoxShadow(color: glow2, blurRadius: 24, spreadRadius: 1, offset: const Offset(0, 12)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Neon icon badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: iconGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: glow1, blurRadius: 14, spreadRadius: 1),
                      ],
                    ),
                    child: Icon(
                      willExceed ? Icons.warning_amber_rounded : Icons.trending_up,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    (AppLocalizations.of(context)?.budgetPredictionTitle ?? 'Prediction'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  // Confidence chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      color: accent.withOpacity(0.12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt, size: 14, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          '${confidence.toString()}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 14),
              Text(
                willExceed
                    ? (AppLocalizations.of(context)?.budgetPredictionWillExceed ?? "You're likely to exceed your budget")
                    : (AppLocalizations.of(context)?.budgetPredictionOnTrack ?? "You're on track to stay within budget"),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.route, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    (AppLocalizations.of(context)?.budgetPredictionProjectedSpending(
                          projectedSpending.toStringAsFixed(2),
                        ) ?? 'Projected spending: ${projectedSpending.toStringAsFixed(2)}'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(exceed ? Icons.warning_amber_rounded : Icons.shield_moon, size: 14, color: exceed ? accent : accent.withOpacity(0.9)),
                  const SizedBox(width: 6),
                  Text(
                    exceed
                        ? (AppLocalizations.of(context)?.budgetPredictionRiskHigh ?? 'Risk: HIGH')
                        : (AppLocalizations.of(context)?.budgetPredictionRiskLow ?? 'Risk: LOW'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: exceed ? accent : accent.withOpacity(0.9),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  // Small helper widget to keep light theme layout tidier
  class _PredictionContent extends StatelessWidget {
  final String title;
  final String onTrackText;
  final String willExceedText;
  final String projectedLabel;
  final TextStyle? titleStyle;
  final TextStyle? textStyle;
  final TextStyle? subTextStyle;
  final bool willExceed;
  final double projectedSpending;
  final dynamic confidence;

  const _PredictionContent({
    required this.title,
    required this.onTrackText,
    required this.willExceedText,
    required this.projectedLabel,
    required this.titleStyle,
    required this.textStyle,
    required this.subTextStyle,
    required this.willExceed,
    required this.projectedSpending,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              willExceed ? Icons.warning : Icons.trending_up,
              color: willExceed
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(title, style: titleStyle?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${confidence.toString()}%', style: subTextStyle),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          willExceed ? willExceedText : onTrackText,
          style: textStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(projectedLabel, style: textStyle),
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final List<Map<String, dynamic>> insights;

  const _InsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        borderRadius: 20,
        color: FlowColors.glassTint(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to full insights screen
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.take(3).map((insight) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight['message'] ?? '',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final List alerts;

  const _AlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        borderRadius: 20,
        color: FlowColors.glassTint(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Alerts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...alerts.take(3).map((alert) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active),
                title: Text(alert.alertType ?? 'Alert'),
                subtitle: Text(alert.message ?? ''),
                trailing: !alert.wasRead
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BudgetSettingsCard extends StatelessWidget {
  final Budget budget;

  const _BudgetSettingsCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        borderRadius: 20,
        color: FlowColors.glassTint(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _SettingItem(
              icon: Icons.repeat,
              label: 'Recurring',
              value: budget.isRecurring ? 'Yes' : 'No',
            ),
            _SettingItem(
              icon: Icons.arrow_forward,
              label: 'Rollover',
              value: budget.allowRollover ? 'Enabled' : 'Disabled',
            ),
            _SettingItem(
              icon: Icons.notifications,
              label: 'Alert Thresholds',
              value: budget.alertThresholds.map((t) => '$t%').join(', '),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SettingItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
