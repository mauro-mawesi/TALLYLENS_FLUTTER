import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/api_service.dart';

class EditReceiptScreen extends StatefulWidget {
  final Object? receipt;
  const EditReceiptScreen({super.key, this.receipt});

  @override
  State<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends State<EditReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _category;
  DateTime? _date;
  bool _saving = false;
  String? _id;

  @override
  void initState() {
    super.initState();
    final r = widget.receipt;
    if (r is Map<String, dynamic>) {
      _id = r['id']?.toString();
      _merchantCtrl.text = r['merchantName']?.toString() ?? '';
      _amountCtrl.text = r['amount']?.toString() ?? '';
      _category = _normalizeCategory(r['category']?.toString());
      _notesCtrl.text = r['notes']?.toString() ?? '';
      final d = r['purchaseDate']?.toString();
      if (d != null && d.isNotEmpty) {
        _date = DateTime.tryParse(d);
      }
    }
  }

  String? _normalizeCategory(String? raw) {
    if (raw == null) return null;
    final v = raw.toString().trim().toLowerCase();
    // Keys admitidas (alineadas con backend)
    const keys = ['grocery', 'transport', 'food', 'fuel', 'others'];
    if (keys.contains(v)) return v;
    // Español
    if (v == 'mercado') return 'grocery';
    if (v == 'transporte') return 'transport';
    if (v == 'comida') return 'food';
    if (v == 'combustible') return 'fuel';
    if (v == 'otros' || v == 'otro') return 'others';
    // Inglés
    if (v == 'groceries' || v == 'grocery') return 'grocery';
    if (v == 'transport') return 'transport';
    if (v == 'food') return 'food';
    if (v == 'fuel') return 'fuel';
    if (v == 'other' || v == 'others') return 'others';
    // Neerlandés
    if (v == 'boodschappen') return 'grocery';
    if (v == 'vervoer') return 'transport';
    if (v == 'eten') return 'food';
    if (v == 'brandstof') return 'fuel';
    if (v == 'overig') return 'others';
    return null;
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.editReceiptTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _merchantCtrl,
                decoration: InputDecoration(labelText: t.merchantLabel),
                textInputAction: TextInputAction.next,
                validator: (v) => v == null || v.isEmpty ? t.fieldRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                decoration: InputDecoration(labelText: t.amountLabel),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val < 0) return t.invalidAmount;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: const ['grocery','transport','food','fuel','others'].contains(_category) ? _category : null,
                items: [
                  DropdownMenuItem(value: 'grocery', child: Text(t.categoryMarket)),
                  DropdownMenuItem(value: 'transport', child: Text(t.categoryTransport)),
                  DropdownMenuItem(value: 'food', child: Text(t.categoryFood)),
                  DropdownMenuItem(value: 'fuel', child: Text(t.categoryFuel)),
                  DropdownMenuItem(value: 'others', child: Text(t.categoryOther)),
                ],
                decoration: InputDecoration(labelText: t.categoryLabel),
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => (v == null || v.isEmpty) ? t.selectCategory : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_date == null ? t.chooseDate : _date!.toString().split(' ').first),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 1),
                    initialDate: _date ?? now,
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(labelText: t.notesLabel),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _onSave,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(t.saveChanges),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_id == null || _id!.isEmpty) return;
    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtrl.text);
      await sl<ApiService>().updateReceipt(
        id: _id!,
        merchantName: _merchantCtrl.text.trim(),
        category: _category,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        amount: amount,
        purchaseDate: _date,
      );
      if (!mounted) return;
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.changesSaved)));
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
