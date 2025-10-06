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
            onPressed: () => context.push('/budgets/${budget.id}/edit'),
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
              if (progress != null) _SpendingChartCard(budget: budget, progress: progress),

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

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
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

  const _SpendingChartCard({
    required this.budget,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // Generate mock data for demonstration
    final chartData = _generateChartData();

    return BudgetChart(
      data: chartData,
      type: ChartType.line,
      title: 'Spending Trend',
      subtitle: 'Daily spending over time',
      currency: budget.currency,
      maxY: budget.amount * 1.2,
    );
  }

  List<ChartDataPoint> _generateChartData() {
    // Mock data - in real app, this would come from backend
    return [
      const ChartDataPoint(label: 'W1', value: 100),
      const ChartDataPoint(label: 'W2', value: 250),
      const ChartDataPoint(label: 'W3', value: 420),
      const ChartDataPoint(label: 'W4', value: 550),
    ];
  }
}

class _PredictionsCard extends StatelessWidget {
  final Map<String, dynamic> predictions;

  const _PredictionsCard({required this.predictions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final willExceed = predictions['willExceed'] ?? false;
    final projectedSpending = predictions['projectedSpending'] ?? 0.0;
    final confidence = predictions['confidence'] ?? 'medium';

    return Card(
      margin: const EdgeInsets.all(16),
      color: willExceed
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  willExceed ? Icons.warning : Icons.trending_up,
                  color: willExceed
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Prediction',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              willExceed
                  ? 'You\'re likely to exceed your budget'
                  : 'You\'re on track to stay within budget',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Projected spending: ${projectedSpending.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Confidence: ${confidence.toString().toUpperCase()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final List<Map<String, dynamic>> insights;

  const _InsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
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

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
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

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
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
