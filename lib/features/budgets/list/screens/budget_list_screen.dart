import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/features/budgets/list/bloc/budget_list_bloc.dart';
import 'package:recibos_flutter/features/budgets/list/bloc/budget_list_event.dart';
import 'package:recibos_flutter/features/budgets/list/bloc/budget_list_state.dart';
import 'package:recibos_flutter/features/budgets/widgets/widgets.dart';

/// Pantalla principal que muestra la lista de presupuestos del usuario.
/// Incluye filtros por categoría, período y estado, además de opciones para
/// crear, editar y eliminar presupuestos.
class BudgetListScreen extends StatelessWidget {
  const BudgetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BudgetListBloc>()..add(const FetchBudgets()),
      child: const _BudgetListView(),
    );
  }
}

class _BudgetListView extends StatelessWidget {
  const _BudgetListView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filter budgets',
          ),
        ],
      ),
      body: BlocBuilder<BudgetListBloc, BudgetListState>(
        builder: (context, state) {
          if (state is BudgetListLoading) {
            return const BudgetLoadingState(message: 'Loading your budgets...');
          }

          if (state is BudgetListError) {
            return BudgetErrorState(
              message: state.message,
              onRetry: () {
                context.read<BudgetListBloc>().add(const FetchBudgets());
              },
            );
          }

          if (state is BudgetListLoaded) {
            if (state.budgets.isEmpty) {
              return BudgetEmptyState(
                title: state.hasActiveFilters
                    ? 'No budgets match your filters'
                    : 'No Budgets Yet',
                message: state.hasActiveFilters
                    ? 'Try adjusting your filters to see more budgets'
                    : 'Create your first budget to start tracking your spending and achieve your financial goals.',
                onActionPressed: state.hasActiveFilters
                    ? () => context.read<BudgetListBloc>().add(const ClearBudgetFilters())
                    : () => context.push('/budgets/create'),
                actionLabel: state.hasActiveFilters ? 'Clear Filters' : 'Create Budget',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<BudgetListBloc>().add(const RefreshBudgets());
                await Future.delayed(const Duration(seconds: 1));
              },
              child: CustomScrollView(
                slivers: [
                  // Filter chips
                  if (state.hasActiveFilters)
                    SliverToBoxAdapter(
                      child: _FilterChips(
                        selectedCategory: state.categoryFilter,
                        selectedPeriod: state.periodFilter,
                        activeOnly: state.isActiveFilter,
                      ),
                    ),

                  // Summary card
                  SliverToBoxAdapter(
                    child: _BudgetSummaryCard(
                      totalBudgets: state.budgets.length,
                      activeBudgets: state.budgets.where((b) => b.isCurrentlyActive).length,
                    ),
                  ),

                  // Budget list
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final budget = state.budgets[index];

                          return BudgetProgressCard(
                            budget: budget,
                            progress: null, // Progress will be loaded in detail screen
                            showDetails: false,
                            onTap: () => context.push('/budgets/${budget.id}'),
                          );
                        },
                        childCount: state.budgets.length,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/budgets/create');
          if (result == true && context.mounted) {
            // Reload budgets after creating
            context.read<BudgetListBloc>().add(const FetchBudgets());
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Budget'),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final bloc = context.read<BudgetListBloc>();
    final state = bloc.state;

    String? selectedCategory;
    String? selectedPeriod;
    bool activeOnly = false;

    if (state is BudgetListLoaded) {
      selectedCategory = state.categoryFilter;
      selectedPeriod = state.periodFilter;
      activeOnly = state.isActiveFilter ?? false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Filter Budgets',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    selectedCategory = null;
                                    selectedPeriod = null;
                                    activeOnly = false;
                                  });
                                },
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Active only toggle
                          SwitchListTile(
                            title: const Text('Active budgets only'),
                            value: activeOnly,
                            onChanged: (value) {
                              setState(() {
                                activeOnly = value;
                              });
                            },
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Category filter
                          Text(
                            'Category',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              'All',
                              'Food & Dining',
                              'Groceries',
                              'Transportation',
                              'Shopping',
                              'Entertainment',
                            ].map((category) {
                              final isSelected = category == 'All'
                                  ? selectedCategory == null
                                  : selectedCategory == category;
                              return FilterChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    selectedCategory = category == 'All' ? null : category;
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Period filter
                          Text(
                            'Period',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: ['All', 'weekly', 'monthly', 'yearly'].map((period) {
                              final isSelected = period == 'All'
                                  ? selectedPeriod == null
                                  : selectedPeriod == period;
                              return FilterChip(
                                label: Text(period == 'All' ? period : period.capitalize()),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    selectedPeriod = period == 'All' ? null : period;
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          // Apply button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                bloc.add(FetchBudgets(
                                  category: selectedCategory,
                                  period: selectedPeriod,
                                  isActive: activeOnly ? true : null,
                                ));
                                Navigator.pop(context);
                              },
                              child: const Text('Apply Filters'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Widget que muestra chips de filtros activos
class _FilterChips extends StatelessWidget {
  final String? selectedCategory;
  final String? selectedPeriod;
  final bool? activeOnly;

  const _FilterChips({
    this.selectedCategory,
    this.selectedPeriod,
    this.activeOnly,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BudgetListBloc>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (selectedCategory != null)
            Chip(
              label: Text('Category: $selectedCategory'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => bloc.add(const FilterBudgetsByCategory(null)),
            ),
          if (selectedPeriod != null)
            Chip(
              label: Text('Period: ${selectedPeriod!.capitalize()}'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => bloc.add(const FilterBudgetsByPeriod(null)),
            ),
          if (activeOnly == true)
            Chip(
              label: const Text('Active only'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => bloc.add(const FilterBudgetsByStatus(null)),
            ),
        ],
      ),
    );
  }
}

/// Widget que muestra un resumen de los presupuestos
class _BudgetSummaryCard extends StatelessWidget {
  final int totalBudgets;
  final int activeBudgets;

  const _BudgetSummaryCard({
    required this.totalBudgets,
    required this.activeBudgets,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                icon: Icons.account_balance_wallet,
                label: 'Total Budgets',
                value: totalBudgets.toString(),
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SummaryItem(
                icon: Icons.trending_up,
                label: 'Active',
                value: activeBudgets.toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
