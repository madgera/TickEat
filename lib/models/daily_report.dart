import 'sale.dart';

class DailyReport {
  final DateTime date;
  final List<Sale> sales;
  final Map<PaymentMethod, double> totalsByPaymentMethod;
  final Map<String, CategorySummary> categorySummaries;
  final int totalTransactions;
  final double totalRevenue;

  DailyReport({
    required this.date,
    required this.sales,
    required this.totalsByPaymentMethod,
    required this.categorySummaries,
    required this.totalTransactions,
    required this.totalRevenue,
  });

  factory DailyReport.fromSales(DateTime date, List<Sale> sales) {
    final totalsByPaymentMethod = <PaymentMethod, double>{};
    final categorySummaries = <String, CategorySummary>{};
    double totalRevenue = 0;

    // Calcola totali per metodo di pagamento
    for (final paymentMethod in PaymentMethod.values) {
      totalsByPaymentMethod[paymentMethod] = 0;
    }

    for (final sale in sales) {
      totalRevenue += sale.totalAmount;
      totalsByPaymentMethod[sale.paymentMethod] = 
          (totalsByPaymentMethod[sale.paymentMethod] ?? 0) + sale.totalAmount;

      // Raggruppa per categoria
      for (final item in sale.items) {
        final category = item.productName; // Usa il nome del prodotto come categoria per ora
        if (!categorySummaries.containsKey(category)) {
          categorySummaries[category] = CategorySummary(
            categoryName: category,
            totalQuantity: 0,
            totalRevenue: 0,
          );
        }
        categorySummaries[category] = categorySummaries[category]!.copyWith(
          totalQuantity: categorySummaries[category]!.totalQuantity + item.quantity,
          totalRevenue: categorySummaries[category]!.totalRevenue + item.totalPrice,
        );
      }
    }

    return DailyReport(
      date: date,
      sales: sales,
      totalsByPaymentMethod: totalsByPaymentMethod,
      categorySummaries: categorySummaries,
      totalTransactions: sales.length,
      totalRevenue: totalRevenue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'total_transactions': totalTransactions,
      'total_revenue': totalRevenue,
      'cash_total': totalsByPaymentMethod[PaymentMethod.cash] ?? 0,
      'electronic_total': totalsByPaymentMethod[PaymentMethod.electronic] ?? 0,
    };
  }
}

class CategorySummary {
  final String categoryName;
  final int totalQuantity;
  final double totalRevenue;

  CategorySummary({
    required this.categoryName,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  CategorySummary copyWith({
    String? categoryName,
    int? totalQuantity,
    double? totalRevenue,
  }) {
    return CategorySummary(
      categoryName: categoryName ?? this.categoryName,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalRevenue: totalRevenue ?? this.totalRevenue,
    );
  }

  @override
  String toString() {
    return 'CategorySummary(categoryName: $categoryName, totalQuantity: $totalQuantity, totalRevenue: $totalRevenue)';
  }
}
