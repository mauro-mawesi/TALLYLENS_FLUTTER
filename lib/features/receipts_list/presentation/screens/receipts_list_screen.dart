import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/widgets/hero_search_bar.dart';
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

class ReceiptsListScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  const ReceiptsListScreen({super.key, this.initialFilters});

  @override
  State<ReceiptsListScreen> createState() => _ReceiptsListScreenState();
}

class _ReceiptsListScreenState extends State<ReceiptsListScreen> {
  late final ReceiptsListBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<ReceiptsListBloc>();
    if (widget.initialFilters != null && widget.initialFilters!.isNotEmpty) {
      _bloc.add(FetchReceipts(
        category: widget.initialFilters!['category'] as String?,
        merchant: widget.initialFilters!['merchant'] as String?,
      ));
    } else {
      _bloc.add(FetchReceipts());
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: ReceiptsListView(initialFilters: widget.initialFilters),
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
                    _buildBubblesSection(context),
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
      expandedHeight: 96,
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
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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

  Widget _buildBubblesSection(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 4),
        child: MonthlyBubbles(),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppLocalizations t) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: HeroSearchBar(
          hintText: t.searchHint,
          controller: _searchCtrl,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/search', extra: _searchCtrl.text);
          },
          onFilterTap: () async {
            HapticFeedback.lightImpact();
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
          filterTooltip: t.filtersTitle,
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

  Map<String, List<dynamic>> _groupReceiptsByMonth(List<dynamic> receipts) {
    final Map<String, List<dynamic>> grouped = {};

    for (final receipt in receipts) {
      final rawDate = receipt["purchaseDate"]?.toString();
      String monthKey;

      if (rawDate == null || rawDate.isEmpty) {
        monthKey = 'unknown';
      } else {
        final dt = DateTime.tryParse(rawDate);
        if (dt == null) {
          monthKey = 'unknown';
        } else {
          // Format: "YYYY-MM" for sorting
          monthKey = DateFormat('yyyy-MM').format(dt.toLocal());
        }
      }

      if (!grouped.containsKey(monthKey)) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(receipt);
    }

    return grouped;
  }

  String _formatMonthHeader(BuildContext context, String monthKey) {
    if (monthKey == 'unknown') {
      return AppLocalizations.of(context)!.uncategorized;
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month, 1);

    return DateFormat.yMMMM(locale).format(date);
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

    // Group receipts by month
    final groupedReceipts = _groupReceiptsByMonth(receipts);
    final sortedMonthKeys = groupedReceipts.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order (newest first)

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Loading indicator at the end
          if (index >= sortedMonthKeys.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: loadingMore
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const SizedBox.shrink(),
              ),
            );
          }

          final monthKey = sortedMonthKeys[index];
          final monthReceipts = groupedReceipts[monthKey]!;
          final monthHeader = _formatMonthHeader(context, monthKey);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                  child: Text(
                    monthHeader,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FlowColors.text(context),
                    ),
                  ),
                ),
                // GlassCard containing all receipts for this month
                GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: FlowColors.glassTint(context),
                  child: Column(
                    children: [
                      for (var i = 0; i < monthReceipts.length; i++) ...[
                        _ReceiptTile(
                          receipt: monthReceipts[i],
                          t: t,
                        ),
                        if (i < monthReceipts.length - 1)
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
          );
        },
        childCount: sortedMonthKeys.length + (hasMore || loadingMore ? 1 : 0),
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

class _ReceiptTile extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final AppLocalizations t;

  const _ReceiptTile({
    required this.receipt,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final category = (receipt["category"] ?? t.uncategorized).toString();
    final merchant = (receipt["merchantName"] ?? "").toString();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final currency = NumberFormat.simpleCurrency(locale: locale);
    final amountNum = double.tryParse((receipt["amount"]?.toString() ?? receipt["total"]?.toString() ?? "").toString());
    final amount = amountNum != null ? currency.format(amountNum) : '—';
    final rawDate = receipt["purchaseDate"]?.toString();
    final dateStr = (() {
      if (rawDate == null || rawDate.isEmpty) return '';
      final dt = DateTime.tryParse(rawDate);
      if (dt == null) return '';
      return DateFormat.yMMMd(locale).format(dt.toLocal());
    })();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: FlowColors.secondary(context).withOpacity(0.8), width: 3),
        ),
      ),
      child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        merchant.isNotEmpty ? merchant : category,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: FlowColors.text(context),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$dateStr • $category',
        style: TextStyle(color: FlowColors.textSecondary(context)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            t.total,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: FlowColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: FlowColors.text(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/detalle', extra: receipt);
      },
    ));
  }
}
