import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ReceiptsFilter {
  final String? category;
  final String? merchant;
  final DateTimeRange? dateRange;
  final RangeValues? amountRange;

  const ReceiptsFilter({this.category, this.merchant, this.dateRange, this.amountRange});
}

class FiltersSheet extends StatefulWidget {
  final ReceiptsFilter initial;
  const FiltersSheet({super.key, this.initial = const ReceiptsFilter()});

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  final _merchantCtrl = TextEditingController();
  String? _category;
  DateTimeRange? _range;
  RangeValues _amount = const RangeValues(0, 500);

  @override
  void initState() {
    super.initState();
    _category = widget.initial.category;
    _merchantCtrl.text = widget.initial.merchant ?? '';
    _range = widget.initial.dateRange;
    _amount = widget.initial.amountRange ?? const RangeValues(0, 500);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(t.filtersTitle, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                )
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              items: [
                DropdownMenuItem(value: 'market', child: Text(t.categoryMarket)),
                DropdownMenuItem(value: 'transport', child: Text(t.categoryTransport)),
                DropdownMenuItem(value: 'food', child: Text(t.categoryFood)),
                DropdownMenuItem(value: 'fuel', child: Text(t.categoryFuel)),
                DropdownMenuItem(value: 'other', child: Text(t.categoryOther)),
              ],
              decoration: InputDecoration(labelText: t.categoryLabel),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _merchantCtrl,
              decoration: InputDecoration(
                labelText: t.merchantLabel,
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(_range == null
                  ? t.dateRangeChoose
                  : '${_range!.start.toString().split(' ').first} → ${_range!.end.toString().split(' ').first}'),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 1),
                  currentDate: now,
                );
                if (picked != null) setState(() => _range = picked);
              },
            ),
            const SizedBox(height: 12),
            Text(t.amountLabel),
            RangeSlider(
              values: _amount,
              min: 0,
              max: 2000,
              divisions: 40,
              labels: RangeLabels(_amount.start.toStringAsFixed(0), _amount.end.toStringAsFixed(0)),
              onChanged: (v) => setState(() => _amount = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  ReceiptsFilter(
                    category: _category,
                    merchant: _merchantCtrl.text.isEmpty ? null : _merchantCtrl.text,
                    dateRange: _range,
                    amountRange: _amount,
                  ),
                );
              },
              child: Text(t.applyFilters),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
