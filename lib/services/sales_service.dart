import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../models/cart_item.dart';
import '../models/daily_report.dart';
import 'storage_service.dart';

class SalesService extends ChangeNotifier {
  final StorageService _storageService = StorageServiceFactory.create();
  final Uuid _uuid = const Uuid();

  Future<String> processPayment({
    required List<CartItem> cartItems,
    required PaymentMethod paymentMethod,
    double? amountPaid,
    String? cashierName,
    int? deviceId,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('Il carrello è vuoto');
    }

    final totalAmount = cartItems.fold(0.0, (total, item) => total + item.totalPrice);
    
    double? changeGiven;
    if (paymentMethod == PaymentMethod.cash && amountPaid != null) {
      if (amountPaid < totalAmount) {
        throw Exception('Importo pagato insufficiente');
      }
      changeGiven = amountPaid - totalAmount;
    }

    final ticketId = _generateTicketId();
    
    final saleItems = cartItems.map((cartItem) => SaleItem(
      productId: cartItem.product.id!,
      productName: cartItem.product.name,
      unitPrice: cartItem.product.price,
      quantity: cartItem.quantity,
      totalPrice: cartItem.totalPrice,
    )).toList();

    final sale = Sale(
      ticketId: ticketId,
      items: saleItems,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      changeGiven: changeGiven,
      cashierName: cashierName,
      deviceId: deviceId,
    );

    await _storageService.insertSale(sale);
    
    notifyListeners();
    
    return ticketId;
  }

  String _generateTicketId() {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final uuid = _uuid.v4().substring(0, 8).toUpperCase();
    return 'TKT$timestamp$uuid';
  }

  Future<List<Sale>> getTodaySales() async {
    return await _storageService.getSalesForDate(DateTime.now());
  }

  Future<List<Sale>> getSalesForDate(DateTime date) async {
    return await _storageService.getSalesForDate(date);
  }

  Future<DailyReport> generateDailyReport(DateTime date) async {
    final sales = await getSalesForDate(date);
    return DailyReport.fromSales(date, sales);
  }

  Future<DailyReport> getTodayReport() async {
    return await generateDailyReport(DateTime.now());
  }

  Future<void> resetDailyData() async {
    await _storageService.resetDailyData();
    notifyListeners();
  }

  Future<List<Sale>> getAllSales() async {
    return await _storageService.getAllSales();
  }

  // Calcolo statistiche rapide
  Future<Map<String, dynamic>> getQuickStats() async {
    final todaySales = await getTodaySales();
    final totalRevenue = todaySales.fold(0.0, (total, sale) => total + sale.totalAmount);
    final totalTransactions = todaySales.length;
    
    final cashTotal = todaySales
        .where((sale) => sale.paymentMethod == PaymentMethod.cash)
        .fold(0.0, (total, sale) => total + sale.totalAmount);
    
    final electronicTotal = todaySales
        .where((sale) => sale.paymentMethod == PaymentMethod.electronic)
        .fold(0.0, (total, sale) => total + sale.totalAmount);

    return {
      'totalRevenue': totalRevenue,
      'totalTransactions': totalTransactions,
      'cashTotal': cashTotal,
      'electronicTotal': electronicTotal,
    };
  }
}
