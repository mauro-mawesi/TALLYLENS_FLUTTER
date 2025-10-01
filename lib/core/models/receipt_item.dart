import 'product.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  if (v is num) return v.toInt();
  return null;
}

class ReceiptItem {
  final String id;
  final String receiptId;
  final String? productId;
  final String? originalText;
  final double? quantity;
  final double? unitPrice;
  final double? totalPrice;
  final String? currency;
  final String? unit;
  final double? confidence;
  final bool? isVerified;
  final int? position;
  final Product? product;

  ReceiptItem({
    required this.id,
    required this.receiptId,
    this.productId,
    this.originalText,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
    this.currency,
    this.unit,
    this.confidence,
    this.isVerified,
    this.position,
    this.product,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        id: json['id'] as String,
        receiptId: json['receiptId'] as String,
        productId: json['productId'] as String?,
        originalText: json['originalText'] as String?,
        quantity: _toDouble(json['quantity']),
        unitPrice: _toDouble(json['unitPrice']),
        totalPrice: _toDouble(json['totalPrice']),
        currency: json['currency'] as String?,
        unit: json['unit'] as String?,
        confidence: _toDouble(json['confidence']),
        isVerified: json['isVerified'] as bool?,
        position: _toInt(json['position']),
        product: json['product'] != null ? Product.fromJson(json['product'] as Map<String, dynamic>) : null,
      );
}
