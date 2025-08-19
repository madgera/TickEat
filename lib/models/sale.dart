enum PaymentMethod { cash, electronic }

class Sale {
  final int? id;
  final String ticketId;
  final List<SaleItem> items;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final double? amountPaid;
  final double? changeGiven;
  final String? cashierName;
  final int? deviceId;
  final DateTime createdAt;

  Sale({
    this.id,
    required this.ticketId,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.amountPaid,
    this.changeGiven,
    this.cashierName,
    this.deviceId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'total_amount': totalAmount,
      'payment_method': paymentMethod.name,
      'amount_paid': amountPaid,
      'change_given': changeGiven,
      'cashier_name': cashierName,
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map, List<SaleItem> items) {
    return Sale(
      id: map['id']?.toInt(),
      ticketId: map['ticket_id'] ?? '',
      items: items,
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['payment_method'],
        orElse: () => PaymentMethod.cash,
      ),
      amountPaid: map['amount_paid']?.toDouble(),
      changeGiven: map['change_given']?.toDouble(),
      cashierName: map['cashier_name'],
      deviceId: map['device_id']?.toInt(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  @override
  String toString() {
    return 'Sale(id: $id, ticketId: $ticketId, totalAmount: $totalAmount, paymentMethod: $paymentMethod)';
  }
}

class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double totalPrice;

  SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'quantity': quantity,
      'total_price': totalPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id']?.toInt(),
      saleId: map['sale_id']?.toInt(),
      productId: map['product_id']?.toInt() ?? 0,
      productName: map['product_name'] ?? '',
      unitPrice: map['unit_price']?.toDouble() ?? 0.0,
      quantity: map['quantity']?.toInt() ?? 0,
      totalPrice: map['total_price']?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'SaleItem(productName: $productName, quantity: $quantity, totalPrice: $totalPrice)';
  }
}
