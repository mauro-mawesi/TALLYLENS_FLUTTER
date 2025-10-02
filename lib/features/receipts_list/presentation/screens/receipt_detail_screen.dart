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
                    padding: const EdgeInsets.all(16.0),
                    child: GlassCard(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.receipt_long_outlined, color: cs.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  receipt.merchantName ?? (receipt.category ?? t.receiptLabel),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: FlowColors.text(context)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      t.totalLabel(''),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FlowColors.textSecondary(context)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      currency.format(receipt.amount ?? 0),
                                      style: const TextStyle(color: FlowColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    if (receipt.purchaseDate != null) ...[
                                      Icon(Icons.event_outlined, size: 16, color: FlowColors.textSecondary(context)),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat.yMMMd(locale).format(receipt.purchaseDate!.toLocal()),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FlowColors.textSecondary(context)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(child: Center(child: Text(t.noProducts)))
                else
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final it = items[index];
                          final name = it.product?.name ?? it.originalText ?? t.product;
                          final qty = it.quantity ?? 1;
                          final unit = it.unit ?? '';
                          final unitPrice = it.unitPrice ?? 0;
                          final total = it.totalPrice ?? (qty * unitPrice);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: GlassCard(
                              borderRadius: 20,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                onTap: () {
                                  final productId = it.product?.id ?? it.productId;
                                  if (productId != null && productId.isNotEmpty) {
                                    context.push(
                                      '/analytics/product',
                                      extra: {
                                        'productId': productId,
                                        'name': it.product?.name ?? it.originalText,
                                      },
                                    );
                                  }
                                },
                                onLongPress: () {
                                  final next = !(it.isVerified ?? false);
                                  context.read<ReceiptDetailBloc>().add(
                                        ToggleItemVerified(receiptId: it.receiptId, itemId: it.id, isVerified: next),
                                      );
                                },
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: cs.secondary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.shopping_bag_outlined, color: cs.secondary),
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: FlowColors.text(context)),
                                ),
                                subtitle: Text(
                                  '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $unit × \$${unitPrice.toStringAsFixed(2)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FlowColors.textSecondary(context)),
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$' + total.toStringAsFixed(2),
                                      style: const TextStyle(color: FlowColors.primary, fontWeight: FontWeight.w700),
                                    ),
                                    if (it.isVerified ?? false)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Icon(Icons.check_circle, size: 16, color: FlowColors.primary),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: items.length,
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
