double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class Product {
  final String id;
  final String name;
  final String? normalizedName;
  final String? category;
  final String? brand;
  final double? averagePrice;
  final double? lowestPrice;
  final double? highestPrice;
  final double? lastSeenPrice;
  final int? purchaseCount;
  final String? unit;

  Product({
    required this.id,
    required this.name,
    this.normalizedName,
    this.category,
    this.brand,
    this.averagePrice,
    this.lowestPrice,
    this.highestPrice,
    this.lastSeenPrice,
    this.purchaseCount,
    this.unit,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: (json['name'] ?? '').toString(),
        normalizedName: json['normalizedName'] as String?,
        category: json['category'] as String?,
        brand: json['brand'] as String?,
        averagePrice: _toDouble(json['averagePrice']),
        lowestPrice: _toDouble(json['lowestPrice']),
        highestPrice: _toDouble(json['highestPrice']),
        lastSeenPrice: _toDouble(json['lastSeenPrice']),
        purchaseCount: json['purchaseCount'] as int?,
        unit: json['unit'] as String?,
      );

}
