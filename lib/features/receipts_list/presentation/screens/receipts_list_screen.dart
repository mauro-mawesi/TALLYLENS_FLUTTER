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
import 'package:recibos_flutter/core/services/connectivity_service.dart';
import 'package:recibos_flutter/features/receipts_list/presentation/widgets/monthly_bubbles.dart';

class ReceiptsListScreen extends StatelessWidget {
  final Map<String, dynamic>? initialFilters;
  const ReceiptsListScreen({super.key, this.initialFilters});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = sl<ReceiptsListBloc>();
        if (initialFilters != null && initialFilters!.isNotEmpty) {
          bloc.add(FetchReceipts(
            category: initialFilters!['category'] as String?,
            merchant: initialFilters!['merchant'] as String?,
          ));
        } else {
          bloc.add(FetchReceipts());
        }
        return bloc;
      },
      child: ReceiptsListView(initialFilters: initialFilters),
    );
  }
}

class ReceiptsListView extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  const ReceiptsListView({super.key, this.initialFilters});

  @override
  State<ReceiptsListView> createState() => _ReceiptsListViewState();
}

class _ReceiptsListViewState extends State<ReceiptsListView> {
  final ScrollController _scroll = ScrollController();
  Map<String, dynamic>? _currentFilters;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _currentFilters = widget.initialFilters;
    _searchCtrl.addListener(() => setState(() {}));
  }

  void _onScroll() {
    final max = _scroll.position.maxScrollExtent;
    final current = _scroll.position.pixels;
    if (max - current < 400) {
      if (!sl<ConnectivityService>().isOnline) return;
      // Cargar más cuando estamos cerca del final
      final bloc = context.read<ReceiptsListBloc>();
      bloc.add(LoadMoreReceipts());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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
              return _ShimmerList();
            }
            if (state is ReceiptsListLoaded) {
              return RefreshIndicator(
                onRefresh: () async => context.read<ReceiptsListBloc>().add(
                  FetchReceipts(
                    category: _currentFilters?['category'] as String?,
                    merchant: _currentFilters?['merchant'] as String?,
                    dateRange: _currentFilters?['dateRange'] as DateTimeRange?,
                    amountRange: _currentFilters?['amountRange'] as RangeValues?,
                    forceRefresh: true,
                  ),
                ),
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    _buildHeader(context, t),
                    _buildSearchBar(context, t),
                    _offlineBannerIfNeeded(context),
                    // 2.C ERROR CRÍTICO: Padding ajustado para evitar el OVERFLOW
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 8, bottom: 120), // Espacio generoso para el FAB
                      sliver: _buildReceiptsList(context, t, state.receipts, loadingMore: state.loadingMore, hasMore: state.hasMore),
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
      expandedHeight: 320,
      pinned: false,
      floating: false,
      actions: [
        IconButton(
          tooltip: t.filtersTitle,
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: () async {
            final res = await _openFilters(context);
            if (res is ReceiptsFilter) {
              // Aplica filtros
              // ignore: use_build_context_synchronously
              context.read<ReceiptsListBloc>().add(FetchReceipts(
                category: res.category,
                merchant: res.merchant,
                dateRange: res.dateRange,
                amountRange: res.amountRange,
              ));
              setState(() {
                _currentFilters = {
                  'category': res.category,
                  'merchant': res.merchant,
                  'dateRange': res.dateRange,
                  'amountRange': res.amountRange,
                };
              });
            }
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: EdgeInsets.zero,
        background: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
            // Título y subtítulo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.greeting(auth.displayName ?? ''),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.recentReceipts,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FlowColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
            // Bubbles debajo del título
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: MonthlyBubbles(),
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
            controller: _searchCtrl,
            style: Theme.of(context).textTheme.bodyLarge,
            onSubmitted: (value) {
              final v = value.trim();
              final existingMerchant = (_currentFilters != null)
                  ? _currentFilters!['merchant'] as String?
                  : null;
              final nextMerchant = v.isEmpty ? existingMerchant : v;
              context.read<ReceiptsListBloc>().add(FetchReceipts(
                category: _currentFilters?['category'] as String?,
                merchant: nextMerchant,
                dateRange: _currentFilters?['dateRange'] as DateTimeRange?,
                amountRange: _currentFilters?['amountRange'] as RangeValues?,
              ));
              setState(() {
                _currentFilters = {
                  'category': _currentFilters?['category'],
                  'merchant': nextMerchant,
                  'dateRange': _currentFilters?['dateRange'],
                  'amountRange': _currentFilters?['amountRange'],
                };
              });
            },
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        context.read<ReceiptsListBloc>().add(FetchReceipts(
                          category: _currentFilters?['category'] as String?,
                          merchant: _currentFilters?['merchant'] as String?,
                          dateRange: _currentFilters?['dateRange'] as DateTimeRange?,
                          amountRange: _currentFilters?['amountRange'] as RangeValues?,
                        ));
                      },
                    )
                  else
                    IconButton(
                      tooltip: t.filtersTitle,
                      icon: const Icon(Icons.tune),
                      onPressed: () async {
                        final res = await _openFilters(context);
                        if (res is ReceiptsFilter) {
                          // ignore: use_build_context_synchronously
                          context.read<ReceiptsListBloc>().add(FetchReceipts(
                            category: res.category,
                            merchant: res.merchant,
                            dateRange: res.dateRange,
                            amountRange: res.amountRange,
                          ));
                          setState(() {
                            _currentFilters = {
                              'category': res.category,
                              'merchant': res.merchant,
                              'dateRange': res.dateRange,
                              'amountRange': res.amountRange,
                            };
                          });
                        }
                      },
                    ),
                ],
              ),
              hintText: t.searchHint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _offlineBannerIfNeeded(BuildContext context) {
    final online = sl<ConnectivityService>().isOnline;
    final cs = Theme.of(context).colorScheme;
    if (online) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.errorContainer.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.noConnection,
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptsList(BuildContext context, AppLocalizations t, List<dynamic> receipts, {required bool loadingMore, required bool hasMore}) {
    if (receipts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.noReceiptsYet, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => context.push('/add'),
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.addFirstReceipt),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= receipts.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: loadingMore
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const SizedBox.shrink(),
              ),
            );
          }
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
                          // 1.A JERARQUÍA: Etiqueta "Total" localizada sin hacks
                          Text(
                            t.total,
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
        childCount: receipts.length + (hasMore || loadingMore ? 1 : 0),
      ),
    );
  }

  // 3. NAVEGACIÓN: Barra simplificada y corregida
  
}

Future<dynamic> _openFilters(BuildContext context) {
  return showModalBottomSheet(
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
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      itemCount: 8,
      itemBuilder: (_, __) => _ShimmerTile(),
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GlassCard(
        borderRadius: 20,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: _ShimmerBar(),
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () {},
      builder: (context, t, child) {
        return Row(
          children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(height: 10, width: MediaQuery.of(context).size.width * 0.5, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
