double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class Receipt {
  final String id;
  final String? imageUrl;
  final String? category;
  final double? amount;
  final String? currency;
  final String? merchantName;
  final DateTime? purchaseDate;
  final bool? isProcessed;
  final String? notes;

  Receipt({
    required this.id,
    this.imageUrl,
    this.category,
    this.amount,
    this.currency,
    this.merchantName,
    this.purchaseDate,
    this.isProcessed,
    this.notes,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String?,
      category: json['category'] as String?,
      amount: _toDouble(json['amount']) ?? _toDouble(json['total']),
      currency: json['currency'] as String?,
      merchantName: json['merchantName'] as String?,
      purchaseDate: json['purchaseDate'] != null ? DateTime.tryParse(json['purchaseDate'].toString()) : null,
      isProcessed: json['isProcessed'] as bool?,
      notes: json['notes'] as String?,
    );
  }
}
