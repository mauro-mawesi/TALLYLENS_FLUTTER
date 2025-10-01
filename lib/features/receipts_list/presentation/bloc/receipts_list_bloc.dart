import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/services/receipt_service.dart';
import 'receipts_list_event.dart';
import 'receipts_list_state.dart';

class ReceiptsListBloc extends Bloc<ReceiptsListEvent, ReceiptsListState> {
  final ReceiptService _receiptService;

  ReceiptsListBloc({required ReceiptService receiptService})
      : _receiptService = receiptService,
        super(ReceiptsListInitial()) {
    // Registra el manejador para el evento FetchReceipts.
    on<FetchReceipts>(_onFetchReceipts);
  }

  Future<void> _onFetchReceipts(
    FetchReceipts event,
    Emitter<ReceiptsListState> emit,
  ) async {
    try {
      // 1. Emite el estado de carga para que la UI muestre un spinner.
      emit(ReceiptsListLoading());
      
      // 2. Llama al servicio para obtener los datos.
      final receipts = await _receiptService.getReceipts(
        category: event.category,
        merchant: event.merchant,
        dateFrom: event.dateRange?.start,
        dateTo: event.dateRange?.end,
        minAmount: event.amountRange?.start,
        maxAmount: event.amountRange?.end,
      );
      
      // 3. Emite el estado de éxito con los datos cargados.
      emit(ReceiptsListLoaded(receipts));
    } catch (e) {
      // 4. Si ocurre un error, emite el estado de error.
      emit(ReceiptsListError(e.toString()));
    }
  }
}
