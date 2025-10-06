import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/models/budget.dart';

/// Widget compacto para mostrar un presupuesto en una lista.
/// Versión simplificada de BudgetProgressCard para vistas de lista.
class BudgetCard extends StatelessWidget {
  final Budget budget;
  final BudgetProgress? progress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const BudgetCard({
    super.key,
    required this.budget,
    this.progress,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final spent = progress?.currentSpending ?? 0.0;
    final total = budget.amount;
    final percentage = total > 0 ? (spent / total * 100).clamp(0.0, 200.0) : 0.0;

    // Determinar el color según el progreso
    Color progressColor;
    if (percentage > 100) {
      progressColor = colorScheme.error;
    } else if (percentage >= 90) {
      progressColor = Colors.orange;
    } else if (percentage >= 70) {
      progressColor = Colors.amber;
    } else {
      progressColor = colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: progressColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              // Budget info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            budget.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (budget.category != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              budget.category!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${budget.currency} ${spent.toStringAsFixed(2)} / ${total.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: progressColor,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Percentage or trailing widget
              if (trailing != null)
                trailing!
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
