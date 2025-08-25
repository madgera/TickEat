import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/fiscal_data.dart';
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
  
  // Metodi fiscali
  Future<void> saveFiscalConfiguration(Map<String, dynamic> config);
  Future<Map<String, dynamic>?> getFiscalConfiguration();
  Future<int> saveFiscalDocument(FiscalDocument document);
  Future<List<FiscalDocument>> getFiscalDocumentsForDate(DateTime date);
  Future<List<FiscalDocument>> getFiscalDocumentsBetweenDates(DateTime startDate, DateTime endDate);
  Future<void> markDocumentAsTransmitted(String documentId, DateTime transmissionDate);
  Future<int> saveFiscalJournal(FiscalJournal journal);
  Future<FiscalJournal?> getFiscalJournalForDate(DateTime date);
  Future<FiscalJournal?> getFiscalJournalById(String journalId);
  Future<int> getDailyDocumentCount(DateTime date);
  Future<void> updateDailyDocumentCount(DateTime date, int count);
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

  // === IMPLEMENTAZIONI METODI FISCALI ===

  @override
  Future<void> saveFiscalConfiguration(Map<String, dynamic> config) async {
    await _databaseHelper.saveFiscalConfiguration(config);
  }

  @override
  Future<Map<String, dynamic>?> getFiscalConfiguration() async {
    return await _databaseHelper.getFiscalConfiguration();
  }

  @override
  Future<int> saveFiscalDocument(FiscalDocument document) async {
    return await _databaseHelper.saveFiscalDocument(document);
  }

  @override
  Future<List<FiscalDocument>> getFiscalDocumentsForDate(DateTime date) async {
    return await _databaseHelper.getFiscalDocumentsForDate(date);
  }

  @override
  Future<List<FiscalDocument>> getFiscalDocumentsBetweenDates(DateTime startDate, DateTime endDate) async {
    return await _databaseHelper.getFiscalDocumentsBetweenDates(startDate, endDate);
  }

  @override
  Future<void> markDocumentAsTransmitted(String documentId, DateTime transmissionDate) async {
    await _databaseHelper.markDocumentAsTransmitted(documentId, transmissionDate);
  }

  @override
  Future<int> saveFiscalJournal(FiscalJournal journal) async {
    return await _databaseHelper.saveFiscalJournal(journal);
  }

  @override
  Future<FiscalJournal?> getFiscalJournalForDate(DateTime date) async {
    return await _databaseHelper.getFiscalJournalForDate(date);
  }

  @override
  Future<FiscalJournal?> getFiscalJournalById(String journalId) async {
    return await _databaseHelper.getFiscalJournalById(journalId);
  }

  @override
  Future<int> getDailyDocumentCount(DateTime date) async {
    return await _databaseHelper.getDailyDocumentCount(date);
  }

  @override
  Future<void> updateDailyDocumentCount(DateTime date, int count) async {
    await _databaseHelper.updateDailyDocumentCount(date, count);
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

  // === STUB METODI FISCALI (per compatibilità web) ===

  @override
  Future<void> saveFiscalConfiguration(Map<String, dynamic> config) async {
    // Stub per web - in produzione potresti usare localStorage
    if (kDebugMode) {
      print('MemoryStorageService: saveFiscalConfiguration non implementato');
    }
  }

  @override
  Future<Map<String, dynamic>?> getFiscalConfiguration() async {
    if (kDebugMode) {
      print('MemoryStorageService: getFiscalConfiguration non implementato');
    }
    return null;
  }

  @override
  Future<int> saveFiscalDocument(FiscalDocument document) async {
    if (kDebugMode) {
      print('MemoryStorageService: saveFiscalDocument non implementato');
    }
    return 0;
  }

  @override
  Future<List<FiscalDocument>> getFiscalDocumentsForDate(DateTime date) async {
    if (kDebugMode) {
      print('MemoryStorageService: getFiscalDocumentsForDate non implementato');
    }
    return [];
  }

  @override
  Future<List<FiscalDocument>> getFiscalDocumentsBetweenDates(DateTime startDate, DateTime endDate) async {
    if (kDebugMode) {
      print('MemoryStorageService: getFiscalDocumentsBetweenDates non implementato');
    }
    return [];
  }

  @override
  Future<void> markDocumentAsTransmitted(String documentId, DateTime transmissionDate) async {
    if (kDebugMode) {
      print('MemoryStorageService: markDocumentAsTransmitted non implementato');
    }
  }

  @override
  Future<int> saveFiscalJournal(FiscalJournal journal) async {
    if (kDebugMode) {
      print('MemoryStorageService: saveFiscalJournal non implementato');
    }
    return 0;
  }

  @override
  Future<FiscalJournal?> getFiscalJournalForDate(DateTime date) async {
    if (kDebugMode) {
      print('MemoryStorageService: getFiscalJournalForDate non implementato');
    }
    return null;
  }

  @override
  Future<FiscalJournal?> getFiscalJournalById(String journalId) async {
    if (kDebugMode) {
      print('MemoryStorageService: getFiscalJournalById non implementato');
    }
    return null;
  }

  @override
  Future<int> getDailyDocumentCount(DateTime date) async {
    if (kDebugMode) {
      print('MemoryStorageService: getDailyDocumentCount non implementato');
    }
    return 0;
  }

  @override
  Future<void> updateDailyDocumentCount(DateTime date, int count) async {
    if (kDebugMode) {
      print('MemoryStorageService: updateDailyDocumentCount non implementato');
    }
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
