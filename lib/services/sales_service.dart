import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../models/cart_item.dart';
import '../models/daily_report.dart';
import '../config/build_config.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class SalesService extends ChangeNotifier {
  final StorageService _storageService = StorageServiceFactory.create();
  final SyncService _syncService = SyncService();
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
    
    // Sincronizza al server se connesso e la modalità lo supporta
    if (BuildConfig.shouldInitializeSyncService && _syncService.isConnected) {
      await _syncService.syncSale(sale);
      if (kDebugMode) {
        print('Vendita sincronizzata al server: $ticketId');
      }
    } else {
      if (kDebugMode) {
        if (BuildConfig.shouldInitializeSyncService) {
          print('Vendita salvata localmente (server non connesso): $ticketId');
        } else {
          print('Vendita salvata localmente (modalità ${BuildConfig.appMode.name}): $ticketId');
        }
      }
    }
    
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

  // Sincronizza vendite dal server
  Future<void> syncSalesFromServer({DateTime? date}) async {
    if (!_syncService.isConnected) return;
    
    try {
      if (kDebugMode) {
        print('Sincronizzando vendite dal server...');
      }
      
      final targetDate = date ?? DateTime.now();
      final serverSales = await _syncService.getSalesFromServer(targetDate);
      
      if (serverSales.isNotEmpty) {
        for (final saleData in serverSales) {
          // Converti gli items dal formato server
          final itemsList = (saleData['items'] as List<dynamic>).map((item) => SaleItem(
            productId: item['productId'] ?? 0,
            productName: item['productName'] ?? '',
            unitPrice: item['unitPrice']?.toDouble() ?? 0.0,
            quantity: item['quantity']?.toInt() ?? 0,
            totalPrice: item['totalPrice']?.toDouble() ?? 0.0,
          )).toList();
          
          // Converti la struttura dati dal formato server al formato locale
          final localSaleData = {
            'ticket_id': saleData['ticketId'],
            'total_amount': saleData['totalAmount'],
            'payment_method': saleData['paymentMethod'],
            'amount_paid': saleData['amountPaid'],
            'change_given': saleData['changeGiven'],
            'cashier_name': saleData['cashierName'],
            'device_id': saleData['deviceId'],
            'created_at': saleData['createdAt'],
          };
          
          final sale = Sale.fromMap(localSaleData, itemsList);
          
          // Controlla se la vendita esiste già localmente (per evitare duplicati)
          final localSales = await getSalesForDate(sale.createdAt);
          final existingSale = localSales.cast<Sale?>().firstWhere(
            (s) => s?.ticketId == sale.ticketId,
            orElse: () => null,
          );
          
          if (existingSale == null) {
            // Nuova vendita dal server
            await _storageService.insertSale(sale);
            if (kDebugMode) {
              print('Nuova vendita ricevuta dal server: ${sale.ticketId}');
            }
          }
        }
        
        if (kDebugMode) {
          print('Sincronizzazione vendite completata: ${serverSales.length} vendite controllate');
        }
        
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore sincronizzazione vendite dal server: $e');
      }
    }
  }

  // Gestisce vendite remote da altri dispositivi
  Future<void> handleRemoteSale(Map<String, dynamic> data) async {
    try {
      // Se è una richiesta di sync check, controlla aggiornamenti
      if (data['action'] == 'sync_check') {
        await syncSalesFromServer();
        return;
      }
      
      // Altrimenti è una vendita specifica
      // Converti gli items dal formato remoto
      final itemsList = (data['items'] as List<dynamic>).map((item) => SaleItem(
        productId: item['productId'] ?? 0,
        productName: item['productName'] ?? '',
        unitPrice: item['unitPrice']?.toDouble() ?? 0.0,
        quantity: item['quantity']?.toInt() ?? 0,
        totalPrice: item['totalPrice']?.toDouble() ?? 0.0,
      )).toList();
      
      // Converti la struttura dati dal formato remoto al formato locale
      final localSaleData = {
        'ticket_id': data['ticketId'],
        'total_amount': data['totalAmount'],
        'payment_method': data['paymentMethod'],
        'amount_paid': data['amountPaid'],
        'change_given': data['changeGiven'],
        'cashier_name': data['cashierName'],
        'device_id': data['deviceId'],
        'created_at': data['createdAt'],
      };
      
      final sale = Sale.fromMap(localSaleData, itemsList);
      
      if (kDebugMode) {
        print('Ricevuta vendita remota: ${sale.ticketId}');
      }
      
      // Controlla se la vendita esiste già localmente
      final localSales = await getSalesForDate(sale.createdAt);
      final existingSale = localSales.cast<Sale?>().firstWhere(
        (s) => s?.ticketId == sale.ticketId,
        orElse: () => null,
      );
      
      if (existingSale == null) {
        // Nuova vendita
        await _storageService.insertSale(sale);
        notifyListeners();
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Errore gestendo vendita remota: $e');
      }
    }
  }

  // Inizializza sincronizzazione
  void initializeSync() {
    // Ottimizzazione: inizializza sync solo se la modalità build lo richiede
    if (!BuildConfig.shouldInitializeSyncService) {
      if (kDebugMode) {
        print('SalesService: Sync non inizializzato (modalità ${BuildConfig.appMode.name})');
      }
      return;
    }
    
    if (kDebugMode) {
      print('SalesService: Inizializzando sync per modalità ${BuildConfig.appMode.name}');
    }
    
    _syncService.addListener(_onSyncServiceUpdate);
    _syncService.setOnRemoteSaleUpdateCallback(handleRemoteSale);
  }

  void _onSyncServiceUpdate() {
    // Quando lo stato di connessione cambia, sincronizza le vendite
    if (_syncService.isConnected) {
      syncSalesFromServer();
    }
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncServiceUpdate);
    _syncService.removeOnRemoteSaleUpdateCallback();
    super.dispose();
  }
}
