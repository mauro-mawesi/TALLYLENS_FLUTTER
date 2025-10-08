import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/models/budget.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';

/// Widget reutilizable para mostrar el progreso de un presupuesto.
/// Muestra el nombre, monto gastado, monto total, porcentaje y barra de progreso.
class BudgetProgressCard extends StatelessWidget {
  final Budget budget;
  final BudgetProgress? progress;
  final VoidCallback? onTap;
  final bool showDetails;

  const BudgetProgressCard({
    super.key,
    required this.budget,
    this.progress,
    this.onTap,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final spent = progress?.currentSpending ?? 0.0;
    final total = budget.amount;
    final percentage = total > 0 ? (spent / total * 100).clamp(0.0, 200.0) : 0.0;
    final isOverBudget = percentage > 100;
    final isNearLimit = percentage >= 90 && percentage <= 100;

    // Determinar el color según el progreso
    Color progressColor;
    if (isOverBudget) {
      progressColor = colorScheme.error;
    } else if (isNearLimit) {
      progressColor = Colors.orange;
    } else if (percentage >= 70) {
      progressColor = Colors.amber;
    } else {
      progressColor = colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        borderRadius: 20,
        color: FlowColors.glassTint(context),
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name and Category
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            budget.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (budget.category != null) ...[
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(
                                budget.category!,
                                style: theme.textTheme.bodySmall,
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    if (!budget.isCurrentlyActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          budget.isExpired
                              ? (l10n?.budgetStatusExpired ?? 'Expired')
                              : (l10n?.budgetStatusInactive ?? 'Inactive'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 16),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: progressColor,
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 12),

              // Amounts and percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.budgetSpent ?? 'Spent',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${budget.currency} ${spent.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n?.budgetAmount ?? 'Budget',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${budget.currency} ${total.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Percentage indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}% ${l10n?.budgetPercentUsed ?? 'used'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showDetails && progress != null) ...[
                    Text(
                      '${budget.daysRemaining} ${l10n?.budgetDaysLeft ?? 'days left'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),

              // Additional details if requested
              if (showDetails && progress != null) ...[
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: FlowColors.divider(context),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final prog = progress!; // Safe to use ! here because of the null check above
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DetailItem(
                          icon: Icons.receipt,
                          label: l10n?.budgetReceiptsCount ?? 'Receipts',
                          value: '${prog.receiptCount}',
                          theme: theme,
                        ),
                        _DetailItem(
                          icon: Icons.calendar_today,
                          label: l10n?.budgetRemaining ?? 'Remaining',
                          value: '${budget.currency} ${prog.remainingBudget.toStringAsFixed(2)}',
                          theme: theme,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Widget helper para mostrar detalles adicionales
class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
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
