import 'package:equatable/equatable.dart';

abstract class ReceiptDetailEvent extends Equatable {
  const ReceiptDetailEvent();
  @override
  List<Object?> get props => [];
}

class LoadReceiptDetail extends ReceiptDetailEvent {
  final String receiptId;
  const LoadReceiptDetail(this.receiptId);
  @override
  List<Object?> get props => [receiptId];
}

class ToggleItemVerified extends ReceiptDetailEvent {
  final String receiptId;
  final String itemId;
  final bool isVerified;
  const ToggleItemVerified({required this.receiptId, required this.itemId, required this.isVerified});
  @override
  List<Object?> get props => [receiptId, itemId, isVerified];
}

class UpdateItemFields extends ReceiptDetailEvent {
  final String receiptId;
  final String itemId;
  final double? quantity;
  final double? unitPrice;
  final bool? isVerified;
  const UpdateItemFields({
    required this.receiptId,
    required this.itemId,
    this.quantity,
    this.unitPrice,
    this.isVerified,
  });
  @override
  List<Object?> get props => [receiptId, itemId, quantity, unitPrice, isVerified];
}
