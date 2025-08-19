import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../database/database_helper.dart';

abstract class StorageService {
  Future<int> insertProduct(Product product);
  Future<List<Product>> getAllProducts();
  Future<List<Product>> getActiveProducts();
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(int id);
  Future<int> insertSale(Sale sale);
  Future<List<Sale>> getSalesForDate(DateTime date);
  Future<List<Sale>> getAllSales();
  Future<void> resetDailyData();
  Future<void> close();
}

class DatabaseStorageService implements StorageService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  Future<int> insertProduct(Product product) async {
    return await _databaseHelper.insertProduct(product);
  }

  @override
  Future<List<Product>> getAllProducts() async {
    return await _databaseHelper.getAllProducts();
  }

  @override
  Future<List<Product>> getActiveProducts() async {
    return await _databaseHelper.getActiveProducts();
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _databaseHelper.updateProduct(product);
  }

  @override
  Future<void> deleteProduct(int id) async {
    await _databaseHelper.deleteProduct(id);
  }

  @override
  Future<int> insertSale(Sale sale) async {
    return await _databaseHelper.insertSale(sale);
  }

  @override
  Future<List<Sale>> getSalesForDate(DateTime date) async {
    return await _databaseHelper.getSalesForDate(date);
  }

  @override
  Future<List<Sale>> getAllSales() async {
    return await _databaseHelper.getAllSales();
  }

  @override
  Future<void> resetDailyData() async {
    await _databaseHelper.resetDailyData();
  }

  @override
  Future<void> close() async {
    await _databaseHelper.close();
  }
}

class MemoryStorageService implements StorageService {
  final List<Product> _products = [];
  final List<Sale> _sales = [];
  int _nextProductId = 1;
  int _nextSaleId = 1;

  MemoryStorageService() {
    _initSampleData();
  }

  void _initSampleData() {
    _products.addAll([
      Product(
        id: _nextProductId++,
        name: 'Panino con Porchetta',
        price: 5.0,
        category: 'Panini',
        description: 'Panino con porchetta artigianale',
      ),
      Product(
        id: _nextProductId++,
        name: 'Birra Media',
        price: 4.0,
        category: 'Bevande',
        description: 'Birra alla spina 0.4L',
      ),
      Product(
        id: _nextProductId++,
        name: 'Salsiccia alla Griglia',
        price: 6.0,
        category: 'Grill',
        description: 'Salsiccia locale alla griglia',
      ),
      Product(
        id: _nextProductId++,
        name: 'Patatine Fritte',
        price: 3.0,
        category: 'Contorni',
        description: 'Patatine fritte croccanti',
      ),
      Product(
        id: _nextProductId++,
        name: 'Acqua Naturale',
        price: 1.5,
        category: 'Bevande',
        description: 'Bottiglia d\'acqua 0.5L',
      ),
      Product(
        id: _nextProductId++,
        name: 'Tiramisù',
        price: 4.5,
        category: 'Dolci',
        description: 'Tiramisù fatto in casa',
      ),
    ]);
  }

  @override
  Future<int> insertProduct(Product product) async {
    final newProduct = product.copyWith(id: _nextProductId++);
    _products.add(newProduct);
    return newProduct.id!;
  }

  @override
  Future<List<Product>> getAllProducts() async {
    return List.from(_products);
  }

  @override
  Future<List<Product>> getActiveProducts() async {
    return _products.where((p) => p.isActive).toList();
  }

  @override
  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _products[index] = product;
    }
  }

  @override
  Future<void> deleteProduct(int id) async {
    _products.removeWhere((p) => p.id == id);
  }

  @override
  Future<int> insertSale(Sale sale) async {
    final saleWithId = Sale(
      id: _nextSaleId++,
      ticketId: sale.ticketId,
      items: sale.items,
      totalAmount: sale.totalAmount,
      paymentMethod: sale.paymentMethod,
      amountPaid: sale.amountPaid,
      changeGiven: sale.changeGiven,
      cashierName: sale.cashierName,
      deviceId: sale.deviceId,
      createdAt: sale.createdAt,
    );
    _sales.add(saleWithId);
    return saleWithId.id!;
  }

  @override
  Future<List<Sale>> getSalesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return _sales.where((sale) {
      return sale.createdAt.isAfter(startOfDay) && sale.createdAt.isBefore(endOfDay);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Sale>> getAllSales() async {
    return List.from(_sales)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> resetDailyData() async {
    _sales.clear();
  }

  @override
  Future<void> close() async {
    // Niente da fare per la memoria
  }
}

class StorageServiceFactory {
  static StorageService create() {
    if (kIsWeb) {
      return MemoryStorageService();
    } else {
      try {
        return DatabaseStorageService();
      } catch (e) {
        if (kDebugMode) {
          print('Fallback to memory storage: $e');
        }
        return MemoryStorageService();
      }
    }
  }
}
