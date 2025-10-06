import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget para seleccionar el período de un presupuesto.
/// Soporta períodos predefinidos (weekly, monthly, yearly) y personalizados.
class PeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<DateTime>? onStartDateChanged;
  final ValueChanged<DateTime>? onEndDateChanged;

  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.startDate,
    this.endDate,
    this.onStartDateChanged,
    this.onEndDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Period',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Period chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PeriodChip(
                  label: 'Weekly',
                  icon: Icons.view_week,
                  period: 'weekly',
                  selected: selectedPeriod == 'weekly',
                  onSelected: () => onPeriodChanged('weekly'),
                ),
                _PeriodChip(
                  label: 'Monthly',
                  icon: Icons.calendar_month,
                  period: 'monthly',
                  selected: selectedPeriod == 'monthly',
                  onSelected: () => onPeriodChanged('monthly'),
                ),
                _PeriodChip(
                  label: 'Yearly',
                  icon: Icons.calendar_today,
                  period: 'yearly',
                  selected: selectedPeriod == 'yearly',
                  onSelected: () => onPeriodChanged('yearly'),
                ),
                _PeriodChip(
                  label: 'Custom',
                  icon: Icons.date_range,
                  period: 'custom',
                  selected: selectedPeriod == 'custom',
                  onSelected: () => onPeriodChanged('custom'),
                ),
              ],
            ),

            // Custom date pickers (only for custom period)
            if (selectedPeriod == 'custom' && onStartDateChanged != null && onEndDateChanged != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start Date',
                      date: startDate,
                      onDateChanged: onStartDateChanged!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DateField(
                      label: 'End Date',
                      date: endDate,
                      onDateChanged: onEndDateChanged!,
                      minDate: startDate,
                    ),
                  ),
                ],
              ),
            ],

            // Period info
            if (startDate != null && endDate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Duration: ${_calculateDuration(startDate!, endDate!)} days',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _calculateDuration(DateTime start, DateTime end) {
    return end.difference(start).inDays + 1;
  }
}

/// Widget de chip para seleccionar un período
class _PeriodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String period;
  final bool selected;
  final VoidCallback onSelected;

  const _PeriodChip({
    required this.label,
    required this.icon,
    required this.period,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }
}

/// Widget de campo de fecha
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? minDate;
  final DateTime? maxDate;

  const _DateField({
    required this.label,
    required this.date,
    required this.onDateChanged,
    this.minDate,
    this.maxDate,
  });

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: minDate ?? DateTime(2020),
      lastDate: maxDate ?? DateTime(2100),
    );

    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          date != null ? dateFormat.format(date!) : 'Select date',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
