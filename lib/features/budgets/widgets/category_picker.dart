import 'package:flutter/material.dart';

/// Widget para seleccionar la categoría de un presupuesto.
/// Muestra categorías predefinidas comunes con íconos.
class CategoryPicker extends StatelessWidget {
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final bool allowCustom;

  const CategoryPicker({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    this.allowCustom = true,
  });

  static const List<BudgetCategory> defaultCategories = [
    BudgetCategory(name: 'Food & Dining', icon: Icons.restaurant),
    BudgetCategory(name: 'Groceries', icon: Icons.shopping_cart),
    BudgetCategory(name: 'Transportation', icon: Icons.directions_car),
    BudgetCategory(name: 'Shopping', icon: Icons.shopping_bag),
    BudgetCategory(name: 'Entertainment', icon: Icons.movie),
    BudgetCategory(name: 'Health & Fitness', icon: Icons.fitness_center),
    BudgetCategory(name: 'Bills & Utilities', icon: Icons.receipt_long),
    BudgetCategory(name: 'Travel', icon: Icons.flight),
    BudgetCategory(name: 'Education', icon: Icons.school),
    BudgetCategory(name: 'Personal Care', icon: Icons.face),
    BudgetCategory(name: 'Gifts & Donations', icon: Icons.card_giftcard),
    BudgetCategory(name: 'Other', icon: Icons.category),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Category',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (selectedCategory != null)
                  TextButton(
                    onPressed: () => onCategoryChanged(null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select a category to organize your budgets',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Category grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: defaultCategories.length,
              itemBuilder: (context, index) {
                final category = defaultCategories[index];
                final isSelected = selectedCategory == category.name;

                return _CategoryTile(
                  category: category,
                  isSelected: isSelected,
                  onTap: () {
                    if (isSelected) {
                      onCategoryChanged(null);
                    } else {
                      onCategoryChanged(category.name);
                    }
                  },
                );
              },
            ),

            // Custom category option
            if (allowCustom) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showCustomCategoryDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add custom category'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCustomCategoryDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Custom Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Category name',
              hintText: 'e.g., Home Improvement',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  onCategoryChanged(controller.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

/// Widget de tile para una categoría
class _CategoryTile extends StatelessWidget {
  final BudgetCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                category.icon,
                size: 32,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modelo de categoría de presupuesto
class BudgetCategory {
  final String name;
  final IconData icon;

  const BudgetCategory({
    required this.name,
    required this.icon,
  });
}
