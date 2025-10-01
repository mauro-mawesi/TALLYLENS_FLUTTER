import 'package:equatable/equatable.dart';
import 'package:recibos_flutter/core/models/receipt.dart';
import 'package:recibos_flutter/core/models/receipt_item.dart';

abstract class ReceiptDetailState extends Equatable {
  const ReceiptDetailState();
  @override
  List<Object?> get props => [];
}

class ReceiptDetailInitial extends ReceiptDetailState {}

class ReceiptDetailLoading extends ReceiptDetailState {}

class ReceiptDetailLoaded extends ReceiptDetailState {
  final Receipt receipt;
  final List<ReceiptItem> items;
  const ReceiptDetailLoaded({required this.receipt, required this.items});
  @override
  List<Object?> get props => [receipt, items];
}

class ReceiptDetailError extends ReceiptDetailState {
  final String message;
  const ReceiptDetailError(this.message);
  @override
  List<Object?> get props => [message];
}

class ReceiptDetailUnauthorized extends ReceiptDetailState {}
