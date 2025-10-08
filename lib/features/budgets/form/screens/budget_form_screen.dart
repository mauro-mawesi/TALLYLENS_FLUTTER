import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/models/budget.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';

/// Pantalla para crear o editar un presupuesto.
class BudgetFormScreen extends StatefulWidget {
  final String? budgetId;

  const BudgetFormScreen({
    super.key,
    this.budgetId,
  });

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isLoading = false;

  // Form fields
  String? _selectedCategory;
  String _selectedPeriod = 'monthly';
  String _currency = 'USD';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  List<int> _alertThresholds = [50, 75, 90, 100];
  bool _isRecurring = false;
  bool _allowRollover = false;
  Map<String, bool> _notificationChannels = {
    'push': true,
    'email': false,
    'inApp': true,
  };

  final List<String> _categories = [
    'grocery',
    'transport',
    'food',
    'fuel',
    'others',
  ];

  final List<String> _periods = [
    'weekly',
    'monthly',
    'yearly',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.budgetId != null) {
      _loadBudget();
    } else {
      _setDefaultDates();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _setDefaultDates() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0); // Last day of month
  }

  Future<void> _loadBudget() async {
    setState(() => _isLoading = true);
    try {
      final budget = await sl<ApiService>().getBudget(widget.budgetId!);
      if (mounted) {
        setState(() {
          _nameController.text = budget.name;
          _amountController.text = budget.amount.toString();
          _selectedCategory = budget.category;
          _selectedPeriod = budget.period;
          _currency = budget.currency;
          _startDate = budget.startDate;
          _endDate = budget.endDate;
          _alertThresholds = budget.alertThresholds;
          _isRecurring = budget.isRecurring;
          _allowRollover = budget.allowRollover;
          _notificationChannels = budget.notificationChannels.toJson().cast<String, bool>();
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.budgetFormLoadError ?? 'Error loading budget')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is after start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final budgetData = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'amount': double.parse(_amountController.text),
        'period': _selectedPeriod,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
        'currency': _currency,
        'alertThresholds': _alertThresholds,
        'isRecurring': _isRecurring,
        'allowRollover': _allowRollover,
        'notificationChannels': _notificationChannels,
      };

      if (widget.budgetId != null) {
        await sl<ApiService>().updateBudget(widget.budgetId!, budgetData);
      } else {
        await sl<ApiService>().createBudget(budgetData);
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.budgetId != null
                  ? (l10n?.budgetFormUpdateSuccess ?? 'Budget updated successfully')
                  : (l10n?.budgetFormCreateSuccess ?? 'Budget created successfully'),
            ),
          ),
        );
        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.budgetFormSaveError ?? 'Error saving budget')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.budgetId != null;
    final l10n = AppLocalizations.of(context);

    if (_isLoading && isEditing) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? (l10n?.budgetFormEditTitle ?? 'Edit Budget') : (l10n?.budgetFormCreateTitle ?? 'Create Budget')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? (l10n?.budgetFormEditTitle ?? 'Edit Budget') : (l10n?.budgetFormCreateTitle ?? 'Create Budget')),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveBudget,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: [
            // Section: Basic Info
            _SectionHeader(title: l10n?.budgetSectionBasic ?? 'Basic Info'),
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              color: FlowColors.glassTint(context),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n?.budgetFormNameLabel ?? 'Budget Name',
                      hintText: l10n?.budgetFormNameHint ?? 'e.g., Monthly Grocery Budget',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n?.budgetFormNameRequired ?? 'Please enter a budget name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: l10n?.budgetFormCategoryLabel ?? 'Category (Optional)',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n?.budgetFormAllCategories ?? 'All Categories (Global)'),
                      ),
                      ..._categories.map((category) => DropdownMenuItem<String?>(
                            value: category,
                            child: Text(_formatCategory(category)),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: l10n?.budgetFormAmountLabel ?? 'Budget Amount',
                      prefixText: '$_currency ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n?.budgetFormAmountRequired ?? 'Please enter an amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return l10n?.budgetFormAmountInvalid ?? 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: Period
            _SectionHeader(title: l10n?.budgetSectionPeriod ?? 'Period'),
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              color: FlowColors.glassTint(context),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedPeriod,
                    decoration: InputDecoration(
                      labelText: l10n?.budgetFormPeriodLabel ?? 'Period',
                      border: const OutlineInputBorder(),
                    ),
                    items: _periods.map((period) => DropdownMenuItem(
                          value: period,
                          child: Text(_formatPeriod(period)),
                        )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPeriod = value!;
                        _updateDatesForPeriod();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(true),
                          icon: const Icon(Icons.calendar_today),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n?.budgetFormStartDateLabel ?? 'Start Date', style: const TextStyle(fontSize: 12)),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_startDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(false),
                          icon: const Icon(Icons.calendar_today),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n?.budgetFormEndDateLabel ?? 'End Date', style: const TextStyle(fontSize: 12)),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_endDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: Alerts
            _SectionHeader(title: l10n?.budgetSectionAlerts ?? 'Alerts'),
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              color: FlowColors.glassTint(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.budgetFormAlertThresholdsTitle ?? 'Alert Thresholds',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.budgetFormAlertThresholdsSubtitle ?? 'Get notified when you reach these percentages of your budget:',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [50, 75, 90, 100, 110, 125].map((threshold) {
                      final isSelected = _alertThresholds.contains(threshold);
                      return FilterChip(
                        label: Text('$threshold%'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _alertThresholds.add(threshold);
                              _alertThresholds.sort();
                            } else {
                              _alertThresholds.remove(threshold);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: Recurrence
            _SectionHeader(title: l10n?.budgetSectionRecurrence ?? 'Recurrence'),
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: FlowColors.glassTint(context),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n?.budgetFormRecurringTitle ?? 'Recurring Budget'),
                    subtitle: Text(l10n?.budgetFormRecurringSubtitle ?? 'Automatically create for next period'),
                    value: _isRecurring,
                    onChanged: (value) {
                      setState(() => _isRecurring = value);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.8,
                    color: FlowColors.divider(context),
                  ),
                  SwitchListTile(
                    title: Text(l10n?.budgetFormRolloverTitle ?? 'Allow Rollover'),
                    subtitle: Text(l10n?.budgetFormRolloverSubtitle ?? 'Carry unused budget to next period'),
                    value: _allowRollover,
                    onChanged: (value) {
                      setState(() => _allowRollover = value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: Notifications
            _SectionHeader(title: l10n?.budgetSectionNotifications ?? 'Notifications'),
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: FlowColors.glassTint(context),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: Text(l10n?.budgetFormPushNotifications ?? 'Push Notifications'),
                    value: _notificationChannels['push'] ?? true,
                    onChanged: (value) {
                      setState(() {
                        _notificationChannels['push'] = value ?? true;
                      });
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.8,
                    color: FlowColors.divider(context),
                  ),
                  CheckboxListTile(
                    title: Text(l10n?.budgetFormInAppAlerts ?? 'In-App Alerts'),
                    value: _notificationChannels['inApp'] ?? true,
                    onChanged: (value) {
                      setState(() {
                        _notificationChannels['inApp'] = value ?? true;
                      });
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.8,
                    color: FlowColors.divider(context),
                  ),
                  CheckboxListTile(
                    title: Text(l10n?.budgetFormEmailNotifications ?? 'Email Notifications'),
                    value: _notificationChannels['email'] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _notificationChannels['email'] = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Button (large)
            ElevatedButton(
              onPressed: _isLoading ? null : _saveBudget,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? (l10n?.budgetFormUpdateCta ?? 'Update Budget') : (l10n?.budgetFormCreateCta ?? 'Create Budget')),
            ),
          ],
        ),
      ),
    );
  }

  void _updateDatesForPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'weekly':
        _startDate = now;
        _endDate = now.add(const Duration(days: 7));
        break;
      case 'monthly':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case 'yearly':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
        break;
      case 'custom':
        // Keep current dates
        break;
    }
  }

  String _formatCategory(String category) {
    switch (category) {
      case 'grocery':
        return 'Grocery';
      case 'transport':
        return 'Transport';
      case 'food':
        return 'Food & Dining';
      case 'fuel':
        return 'Fuel';
      case 'others':
        return 'Others';
      default:
        return category;
    }
  }

  String _formatPeriod(String period) {
    switch (period) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      case 'custom':
        return 'Custom Period';
      default:
        return period;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: FlowColors.text(context),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
