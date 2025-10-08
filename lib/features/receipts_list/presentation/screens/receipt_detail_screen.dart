import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/models/receipt.dart';
import 'package:recibos_flutter/core/models/receipt_item.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/services/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:recibos_flutter/features/receipt_detail/bloc/receipt_detail_bloc.dart';
import 'package:recibos_flutter/features/receipt_detail/bloc/receipt_detail_event.dart';
import 'package:recibos_flutter/features/receipt_detail/bloc/receipt_detail_state.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/widgets/receipt_ticket_header.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/widgets/receipt_paper_header.dart';

class ReceiptDetailScreen extends StatelessWidget {
  final Object? receipt;
  const ReceiptDetailScreen({super.key, this.receipt});

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    String receiptId = '';
    if (r is Map<String, dynamic>) {
      receiptId = (r['id'] ?? '').toString();
    }
    return BlocProvider(
      create: (_) => ReceiptDetailBloc(api: sl<ApiService>())..add(LoadReceiptDetail(receiptId)),
      child: const _ReceiptDetailView(),
    );
  }
}

class _ReceiptDetailView extends StatelessWidget {
  const _ReceiptDetailView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.receiptDetailTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () async {
              final st = context.read<ReceiptDetailBloc>().state;
              if (st is! ReceiptDetailLoaded) return;
              final receipt = st.receipt;
              final items = st.items;
              final pdf = await PdfService().buildReceiptPdf(
                receipt: receipt,
                items: items,
                locale: Localizations.localeOf(context),
              );
              final dir = await getTemporaryDirectory();
              final path = '${dir.path}/receipt_${receipt.id}.pdf';
              final f = File(path);
              await f.writeAsBytes(pdf, flush: true);
              await Share.shareXFiles([XFile(f.path)], subject: 'Receipt ${receipt.id}');
            },
          ),
          IconButton(
            tooltip: t.editReceiptTitle,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final s = context.read<ReceiptDetailBloc>().state;
              if (s is ReceiptDetailLoaded) {
                final r = s.receipt;
                final map = {
                  'id': r.id,
                  'merchantName': r.merchantName,
                  'amount': r.amount,
                  'category': r.category,
                  'notes': r.notes,
                  'purchaseDate': r.purchaseDate?.toIso8601String(),
                };
                final updated = await context.push<bool>('/edit', extra: map);
                if (updated == true && context.mounted) {
                  context.read<ReceiptDetailBloc>().add(LoadReceiptDetail(r.id));
                }
              }
            },
          ),
          IconButton(
            tooltip: t.viewImage,
            icon: const Icon(Icons.image_outlined),
            onPressed: () async {
              final s = context.read<ReceiptDetailBloc>().state;
              if (s is ReceiptDetailLoaded) {
                final id = s.receipt.id;
                if (context.mounted) {
                  context.push('/receipt-image', extra: {'id': id});
                }
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: FlowColors.backgroundGradient(context),
          ),
        ),
        child: BlocListener<ReceiptDetailBloc, ReceiptDetailState>(
          listenWhen: (prev, curr) => curr is ReceiptDetailUnauthorized,
          listener: (context, state) {
            if (state is ReceiptDetailUnauthorized) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.sessionExpired)),
                );
                context.go('/unlock');
              }
            }
          },
          child: BlocBuilder<ReceiptDetailBloc, ReceiptDetailState>(
          builder: (context, state) {
            if (state is ReceiptDetailLoading || state is ReceiptDetailInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ReceiptDetailError) {
              return Center(child: Text('${t.errorPrefix(state.message)}'));
            }
            if (state is ReceiptDetailLoaded) {
              final receipt = state.receipt;
              final items = state.items;
            final locale = Localizations.localeOf(context).toLanguageTag();
            final currency = NumberFormat.simpleCurrency(locale: locale);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: ReceiptPaperHeader(receipt: receipt, items: items),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(child: Center(child: Text(t.noProducts)))
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                            child: Text(
                              t.products,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: FlowColors.text(context),
                              ),
                            ),
                          ),
                          GlassCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: FlowColors.glassTint(context),
                            child: Column(
                              children: [
                                for (var i = 0; i < items.length; i++) ...[
                                  _ItemTile(
                                    item: items[i],
                                    receipt: receipt,
                                    locale: locale,
                                    t: t,
                                    cs: cs,
                                  ),
                                  if (i < items.length - 1)
                                    Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                      thickness: 0.8,
                                      color: FlowColors.divider(context),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
            }
            return const SizedBox.shrink();
          },
        ),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final ReceiptItem item;
  final Receipt receipt;
  final String locale;
  final AppLocalizations t;
  final ColorScheme cs;

  const _ItemTile({
    required this.item,
    required this.receipt,
    required this.locale,
    required this.t,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final name = item.product?.name ?? item.originalText ?? t.product;
    final qty = item.quantity ?? 1;
    final unit = item.unit ?? '';
    final unitPrice = item.unitPrice ?? 0;
    final total = item.totalPrice ?? (qty * unitPrice);
    final itemFmt = NumberFormat.simpleCurrency(
      locale: locale,
      name: item.currency ?? receipt.currency,
    );
    final unitPriceStr = itemFmt.format(unitPrice);
    final totalStr = itemFmt.format(total);

    return Container(
      decoration: BoxDecoration(
        border: (item.isVerified ?? false)
            ? Border(left: BorderSide(color: FlowColors.primary.withOpacity(0.9), width: 3))
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () {
        final productId = item.product?.id ?? item.productId;
        if (productId != null && productId.isNotEmpty) {
          context.push(
            '/analytics/product',
            extra: {
              'productId': productId,
              'name': item.product?.name ?? item.originalText,
            },
          );
        }
      },
      onLongPress: () {
        final next = !(item.isVerified ?? false);
        context.read<ReceiptDetailBloc>().add(
          ToggleItemVerified(receiptId: item.receiptId, itemId: item.id, isVerified: next),
        );
      },
      leading: null,
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: FlowColors.text(context),
        ),
      ),
      subtitle: Text(
        '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $unit × $unitPriceStr',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: FlowColors.textSecondary(context),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: FlowColors.glassTint(context),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FlowColors.divider(context), width: 0.8),
            ),
            child: Text(
              totalStr,
              style: TextStyle(
                color: FlowColors.text(context),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (item.isVerified ?? false)
            const Icon(Icons.check_circle, size: 16, color: FlowColors.primary),
          const SizedBox(width: 6),
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: t.editReceiptTitle,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEditItemSheet(context, item),
          ),
        ],
      ),
      ),
    );
  }
}

Future<void> _openEditItemSheet(BuildContext context, ReceiptItem it) async {
  final qtyCtrl = TextEditingController(text: (it.quantity ?? 1).toString());
  final priceCtrl = TextEditingController(text: (it.unitPrice ?? 0).toStringAsFixed(2));
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(AppLocalizations.of(ctx)!.editReceiptTitle, style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Unit price'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: Text(AppLocalizations.of(ctx)!.saveChanges),
                onPressed: () {
                  final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.'));
                  final p = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                  ctx.read<ReceiptDetailBloc>().add(UpdateItemFields(
                    receiptId: it.receiptId,
                    itemId: it.id,
                    quantity: q,
                    unitPrice: p,
                  ));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
