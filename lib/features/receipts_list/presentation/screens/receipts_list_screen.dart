import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/bloc/receipts_list_bloc.dart';
import '../bloc/receipts_list_event.dart';
import '../bloc/receipts_list_state.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/widgets/filters_sheet.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class ReceiptsListScreen extends StatelessWidget {
  const ReceiptsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ReceiptsListBloc>()..add(FetchReceipts()),
      child: const ReceiptsListView(),
    );
  }
}

class ReceiptsListView extends StatelessWidget {
  const ReceiptsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: FlowColors.backgroundGradient(context),
          ),
        ),
        child: BlocBuilder<ReceiptsListBloc, ReceiptsListState>(
          builder: (context, state) {
            if (state is ReceiptsListLoading || state is ReceiptsListInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ReceiptsListLoaded) {
              return RefreshIndicator(
                onRefresh: () async => context.read<ReceiptsListBloc>().add(FetchReceipts()),
                child: CustomScrollView(
                  slivers: [
                    _buildHeader(context, t),
                    _buildSearchBar(context, t),
                    // 2.C ERROR CRÍTICO: Padding ajustado para evitar el OVERFLOW
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 8, bottom: 120), // Espacio generoso para el FAB
                      sliver: _buildReceiptsList(context, t, state.receipts),
                    ),
                  ],
                ),
              );
            }
            if (state is ReceiptsListError) {
              return Center(child: Text('${t.errorPrefix(state.message)}'));
            }
            return Center(child: Text(t.unhandledState));
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations t) {
    final auth = sl<AuthService>();
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 96,
      actions: [
        IconButton(
          tooltip: t.filtersTitle,
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: () async {
            final res = await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: const FiltersSheet(),
              ),
            );
            if (res is ReceiptsFilter) {
              // Aplica filtros
              // ignore: use_build_context_synchronously
              context.read<ReceiptsListBloc>().add(FetchReceipts(
                category: res.category,
                merchant: res.merchant,
                dateRange: res.dateRange,
                amountRange: res.amountRange,
              ));
            }
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.greeting(auth.displayName ?? ''),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              t.recentReceipts,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FlowColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppLocalizations t) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.mic_none),
              hintText: '',
            ).copyWith(hintText: t.searchHint),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptsList(BuildContext context, AppLocalizations t, List<dynamic> receipts) {
    if (receipts.isEmpty) {
      return SliverFillRemaining(child: Center(child: Text(t.noReceiptsYet)));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final r = receipts[index];
          final category = (r["category"] ?? t.uncategorized).toString();
          final merchant = (r["merchantName"] ?? "").toString();
          final locale = Localizations.localeOf(context).toLanguageTag();
          final currency = NumberFormat.simpleCurrency(locale: locale);
          final amountNum = double.tryParse((r["amount"]?.toString() ?? r["total"]?.toString() ?? "").toString());
          final amount = amountNum != null ? currency.format(amountNum) : '—';
          final rawDate = r["purchaseDate"]?.toString();
          final dateStr = (() {
            if (rawDate == null || rawDate.isEmpty) return '';
            final dt = DateTime.tryParse(rawDate);
            if (dt == null) return '';
            return DateFormat.yMMMd(locale).format(dt.toLocal());
          })();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            // 2.A Aplicar glass tint dependiente del tema
            child: GlassCard(
              borderRadius: 20,
              color: FlowColors.glassTint(context),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/detalle', extra: r);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // 2.B ICONOGRAFÍA: Corregido
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: FlowColors.secondary(context).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined, // Icono de contorno fino
                          color: FlowColors.secondary(context), // Acento Neón
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1.A JERARQUÍA: Título principal
                            Text(
                              merchant.isNotEmpty ? merchant : category,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: FlowColors.text(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 1.A JERARQUÍA: Información secundaria
                            Text(
                              '$dateStr • $category',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FlowColors.textSecondary(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // 1.A JERARQUÍA: Etiqueta "Total"
                          Text(
                            '${t.totalLabel('')}'.replaceAll(': ', ''),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FlowColors.textSecondary(context)),
                          ),
                          const SizedBox(height: 2),
                          // 1.B USO DE ACENTOS: Monto con acento primario
                          Text(
                            amount,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: FlowColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: receipts.length,
      ),
    );
  }

  // 3. NAVEGACIÓN: Barra simplificada y corregida
  
}
