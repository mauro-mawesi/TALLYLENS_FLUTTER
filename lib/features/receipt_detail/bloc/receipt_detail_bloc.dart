import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recibos_flutter/core/models/receipt.dart';
import 'package:recibos_flutter/core/models/receipt_item.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'receipt_detail_event.dart';
import 'receipt_detail_state.dart';
import 'package:recibos_flutter/core/services/errors.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';

class ReceiptDetailBloc extends Bloc<ReceiptDetailEvent, ReceiptDetailState> {
  final ApiService api;
  ReceiptDetailBloc({required this.api}) : super(ReceiptDetailInitial()) {
    on<LoadReceiptDetail>(_onLoad);
    on<ToggleItemVerified>(_onToggleVerified);
    on<UpdateItemFields>(_onUpdateItemFields);
  }

  Future<void> _onLoad(LoadReceiptDetail event, Emitter<ReceiptDetailState> emit) async {
    try {
      emit(ReceiptDetailLoading());
      final recJson = await api.getReceiptById(event.receiptId);
      final itemsJson = await api.getReceiptItems(event.receiptId);
      final receipt = Receipt.fromJson(recJson);
      final items = itemsJson.map<ReceiptItem>((e) => ReceiptItem.fromJson(e as Map<String, dynamic>)).toList();
      emit(ReceiptDetailLoaded(receipt: receipt, items: items));
    } catch (e) {
      if (e is UnauthorizedException) {
        sl<AuthService>().forceLock();
        emit(ReceiptDetailUnauthorized());
      } else {
        emit(ReceiptDetailError(e.toString()));
      }
    }
  }

  Future<void> _onToggleVerified(ToggleItemVerified event, Emitter<ReceiptDetailState> emit) async {
    final current = state;
    if (current is! ReceiptDetailLoaded) return;
    try {
      final updatedItems = current.items.map((it) => it.id == event.itemId ? ReceiptItem(
        id: it.id,
        receiptId: it.receiptId,
        productId: it.productId,
        originalText: it.originalText,
        quantity: it.quantity,
        unitPrice: it.unitPrice,
        totalPrice: it.totalPrice,
        currency: it.currency,
        unit: it.unit,
        confidence: it.confidence,
        isVerified: event.isVerified,
        position: it.position,
        product: it.product,
      ) : it).toList();
      emit(ReceiptDetailLoaded(receipt: current.receipt, items: updatedItems));

      await api.updateReceiptItem(
        receiptId: event.receiptId,
        itemId: event.itemId,
        isVerified: event.isVerified,
      );
    } catch (e) {
      if (e is UnauthorizedException) {
        sl<AuthService>().forceLock();
        emit(ReceiptDetailUnauthorized());
      } else {
        emit(ReceiptDetailError(e.toString()));
      }
    }
  }

  Future<void> _onUpdateItemFields(UpdateItemFields event, Emitter<ReceiptDetailState> emit) async {
    final current = state;
    if (current is! ReceiptDetailLoaded) return;
    try {
      // Optimistic update
      final updatedItems = current.items.map((it) {
        if (it.id != event.itemId) return it;
        final q = event.quantity ?? it.quantity;
        final up = event.unitPrice ?? it.unitPrice;
        final tot = (q ?? 1) * (up ?? 0);
        return ReceiptItem(
          id: it.id,
          receiptId: it.receiptId,
          productId: it.productId,
          originalText: it.originalText,
          quantity: q,
          unitPrice: up,
          totalPrice: tot,
          currency: it.currency,
          unit: it.unit,
          confidence: it.confidence,
          isVerified: event.isVerified ?? it.isVerified,
          position: it.position,
          product: it.product,
        );
      }).toList();
      emit(ReceiptDetailLoaded(receipt: current.receipt, items: updatedItems));

      await api.updateReceiptItem(
        receiptId: event.receiptId,
        itemId: event.itemId,
        quantity: event.quantity,
        unitPrice: event.unitPrice,
        isVerified: event.isVerified,
      );
    } catch (e) {
      if (e is UnauthorizedException) {
        sl<AuthService>().forceLock();
        emit(ReceiptDetailUnauthorized());
      } else {
        emit(ReceiptDetailError(e.toString()));
      }
    }
  }
}
