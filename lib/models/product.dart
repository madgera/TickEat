import 'fiscal_data.dart';

class Product {
  final int? id;
  final String name;
  final double price;
  final String category;
  final bool isActive;
  final String? description;
  final VatRate vatRate;  // Aliquota IVA del prodotto
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    this.isActive = true,
    this.description,
    this.vatRate = VatRate.standard,  // IVA standard di default
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'is_active': isActive ? 1 : 0,
      'description': description,
      'vat_rate': vatRate.rate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      price: map['price']?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      isActive: map['is_active'] == 1,
      description: map['description'],
      vatRate: VatRate.values.firstWhere(
        (rate) => rate.rate == (map['vat_rate'] ?? 22.0),
        orElse: () => VatRate.standard,
      ),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    String? category,
    bool? isActive,
    String? description,
    VatRate? vatRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      vatRate: vatRate ?? this.vatRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, category: $category, isActive: $isActive)';
  }
}
