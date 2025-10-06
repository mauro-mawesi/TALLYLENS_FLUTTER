import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/receipt_service.dart';
import 'receipts_list_event.dart';
import 'receipts_list_state.dart';

class ReceiptsListBloc extends Bloc<ReceiptsListEvent, ReceiptsListState> {
  final ReceiptService _receiptService;
  static const int _pageSize = 20;
  String? _category;
  String? _merchant;
  DateTimeRange? _dateRange;
  RangeValues? _amountRange;
  bool _isFetching = false;

  ReceiptsListBloc({required ReceiptService receiptService})
      : _receiptService = receiptService,
        super(ReceiptsListInitial()) {
    on<FetchReceipts>(_onFetchReceipts);
    on<LoadMoreReceipts>(_onLoadMore);
  }

  Future<void> _onFetchReceipts(
    FetchReceipts event,
    Emitter<ReceiptsListState> emit,
  ) async {
    // Evitar peticiones duplicadas simultáneas
    if (_isFetching) return;

    _category = event.category;
    _merchant = event.merchant;
    _dateRange = event.dateRange;
    _amountRange = event.amountRange;
    try {
      _isFetching = true;
      // 1. Emite el estado de carga para que la UI muestre un shimmer/spinner.
      emit(ReceiptsListLoading());
      // 2. Llama al servicio para obtener la primera página (con cache si existe)
      final page1 = await _receiptService.getReceiptsPaged(
        category: _category,
        merchant: _merchant,
        dateFrom: _dateRange?.start,
        dateTo: _dateRange?.end,
        minAmount: _amountRange?.start,
        maxAmount: _amountRange?.end,
        page: 1,
        pageSize: _pageSize,
        forceRefresh: event.forceRefresh,
      );

      // 3. Emite el estado de éxito con los datos cargados.
      emit(ReceiptsListLoaded(
        receipts: page1.items,
        hasMore: page1.hasMore,
        loadingMore: false,
        page: 1,
        pageSize: _pageSize,
      ));
    } catch (e) {
      // 4. Si ocurre un error, emite el estado de error.
      emit(ReceiptsListError(e.toString()));
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _onLoadMore(
    LoadMoreReceipts event,
    Emitter<ReceiptsListState> emit,
  ) async {
    final current = state;
    if (current is! ReceiptsListLoaded) return;
    if (!current.hasMore || current.loadingMore) return;
    emit(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final pageRes = await _receiptService.getReceiptsPaged(
        category: _category,
        merchant: _merchant,
        dateFrom: _dateRange?.start,
        dateTo: _dateRange?.end,
        minAmount: _amountRange?.start,
        maxAmount: _amountRange?.end,
        page: nextPage,
        pageSize: current.pageSize,
      );
      final merged = [...current.receipts, ...pageRes.items];
      emit(current.copyWith(
        receipts: merged,
        hasMore: pageRes.hasMore,
        loadingMore: false,
        page: nextPage,
      ));
    } catch (e) {
      // fall back: detener loadingMore pero mantener lista
      emit(current.copyWith(loadingMore: false));
    }
  }
}
