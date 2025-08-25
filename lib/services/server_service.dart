import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/fiscal_data.dart';
import '../models/daily_report.dart';
import 'storage_service.dart';

enum ServerStatus { stopped, starting, running, error }

class ServerService extends ChangeNotifier {
  static final ServerService _instance = ServerService._internal();
  ServerService._internal();
  factory ServerService() => _instance;

  // Stato del server
  ServerStatus _status = ServerStatus.stopped;
  String? _serverAddress;
  int _serverPort = 3000;
  HttpServer? _httpServer;
  
  // Dispositivi connessi
  final List<ConnectedDevice> _connectedDevices = [];
  final StorageService _storageService = StorageServiceFactory.create();
  
  // Callback per notificare aggiornamenti ai servizi locali
  Function()? _onProductUpdated;
  Function()? _onSaleUpdated;

  // Getters
  ServerStatus get status => _status;
  String? get serverAddress => _serverAddress;
  int get serverPort => _serverPort;
  List<ConnectedDevice> get connectedDevices => List.unmodifiable(_connectedDevices);
  bool get isRunning => _status == ServerStatus.running;

  // Avvia il server
  Future<bool> startServer({int? port}) async {
    if (_status == ServerStatus.running) return true;

    // Controlla se la piattaforma supporta il server HTTP
    if (kIsWeb) {
      if (kDebugMode) {
        print('Modalità server non supportata su web browser');
      }
      _updateStatus(ServerStatus.error);
      return false;
    }

    try {
      _updateStatus(ServerStatus.starting);
      
      _serverPort = port ?? 3000;
      
      // Ottieni l'indirizzo IP locale
      _serverAddress = await _getLocalIPAddress();
      
      // Avvia il server HTTP con binding migliorato
      InternetAddress bindAddress;
      try {
        // Prova prima a bindare su tutte le interfacce
        bindAddress = InternetAddress.anyIPv4;
        _httpServer = await HttpServer.bind(bindAddress, _serverPort);
        
        if (kDebugMode) {
          print('TickEat PRO Server avviato su tutte le interfacce (0.0.0.0:$_serverPort)');
          print('Server raggiungibile su:');
          print('  - Locale: http://localhost:$_serverPort');
          print('  - Rete: http://$_serverAddress:$_serverPort');
          
          // Mostra tutti gli IP disponibili
          final interfaces = await NetworkInterface.list();
          for (final interface in interfaces) {
            for (final address in interface.addresses) {
              if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
                print('  - ${interface.name}: http://${address.address}:$_serverPort');
              }
            }
          }
        }
      } catch (e) {
        // Fallback per piattaforme che non supportano anyIPv4
        bindAddress = InternetAddress.loopbackIPv4;
        _httpServer = await HttpServer.bind(bindAddress, _serverPort);
        
        if (kDebugMode) {
          print('Fallback a loopback address: $e');
          print('Server avviato solo su localhost:$_serverPort');
        }
      }

      // Gestisci le richieste
      _httpServer!.listen(_handleRequest);
      
      // Salva configurazione
      await _saveServerConfig();
      
      _updateStatus(ServerStatus.running);
      return true;
      
    } catch (e) {
      if (kDebugMode) {
        print('Errore avvio server: $e');
      }
      _updateStatus(ServerStatus.error);
      return false;
    }
  }

  // Ferma il server
  Future<void> stopServer() async {
    try {
      await _httpServer?.close();
      _httpServer = null;
      _connectedDevices.clear();
      _updateStatus(ServerStatus.stopped);
      
      if (kDebugMode) {
        print('TickEat PRO Server fermato');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore fermando server: $e');
      }
    }
  }

  // Gestisce le richieste HTTP
  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    
    // Abilita CORS per permettere richieste da app web
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Device-ID, Device-Name');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }

    try {
      final path = request.uri.path;
      final deviceId = request.headers.value('Device-ID');
      final deviceName = request.headers.value('Device-Name');

      // Registra dispositivo se non esiste
      if (deviceId != null && deviceName != null) {
        _registerDevice(deviceId, deviceName, request.connectionInfo!.remoteAddress);
      }

      switch (path) {
        case '/api/health':
          await _handleHealthCheck(request, response);
          break;
        case '/api/sales':
          if (request.method == 'POST') {
            await _handleCreateSale(request, response);
          } else if (request.method == 'GET') {
            await _handleGetSales(request, response);
          }
          break;
        case '/api/products':
          if (request.method == 'POST') {
            await _handleCreateProduct(request, response);
          } else if (request.method == 'GET') {
            await _handleGetProducts(request, response);
          }
          break;
        case '/api/reports/consolidated':
          await _handleGetConsolidatedReport(request, response);
          break;
        case '/api/devices':
          await _handleGetDevices(request, response);
          break;
        case '/api/sales/by-device':
          await _handleGetSalesByDevice(request, response);
          break;
        default:
          response.statusCode = HttpStatus.notFound;
          response.write(json.encode({'error': 'Endpoint non trovato'}));
      }
    } catch (e) {
      response.statusCode = HttpStatus.internalServerError;
      response.write(json.encode({'error': 'Errore interno server: $e'}));
      
      if (kDebugMode) {
        print('Errore gestendo richiesta: $e');
      }
    } finally {
      await response.close();
    }
  }

  // Health check
  Future<void> _handleHealthCheck(HttpRequest request, HttpResponse response) async {
    response.statusCode = HttpStatus.ok;
    response.write(json.encode({
      'status': 'healthy',
      'server': 'TickEat PRO Server',
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'connectedDevices': _connectedDevices.length,
    }));
  }

  // Gestisci creazione vendita
  Future<void> _handleCreateSale(HttpRequest request, HttpResponse response) async {
    if (kDebugMode) {
      print('=== SERVER: RICEVUTA RICHIESTA VENDITA ===');
      print('Method: ${request.method}');
      print('Path: ${request.uri.path}');
      print('Headers: ${request.headers}');
    }
    
    try {
      final body = await utf8.decoder.bind(request).join();
      if (kDebugMode) {
        print('Body ricevuto: $body');
      }
      
      final data = json.decode(body);
      if (kDebugMode) {
        print('Dati parsed: $data');
      }

      // Converti in Sale object con gestione errori migliore
      final saleItems = (data['items'] as List).map((item) {
        final vatRate = VatRate.values.firstWhere(
          (rate) => rate.rate == (item['vatRate'] ?? 22.0),
          orElse: () => VatRate.standard,
        );
        final vatCalculation = VatCalculation.fromGross(
          item['totalPrice']?.toDouble() ?? 0.0, 
          vatRate
        );
        
        return SaleItem(
          productId: item['productId']?.toInt() ?? 0,
          productName: item['productName']?.toString() ?? '',
          unitPrice: item['unitPrice']?.toDouble() ?? 0.0,
          quantity: item['quantity']?.toInt() ?? 0,
          totalPrice: item['totalPrice']?.toDouble() ?? 0.0,
          vatCalculation: vatCalculation,
        );
      }).toList();

      if (kDebugMode) {
        print('Items convertiti: ${saleItems.length}');
      }

      final sale = Sale(
        ticketId: data['ticketId']?.toString() ?? '',
        items: saleItems,
        totalAmount: data['totalAmount']?.toDouble() ?? 0.0,
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == data['paymentMethod'],
          orElse: () => PaymentMethod.cash,
        ),
        amountPaid: data['amountPaid']?.toDouble(),
        changeGiven: data['changeGiven']?.toDouble(),
        cashierName: data['cashierName']?.toString(),
        deviceId: data['deviceId'] is String ? int.tryParse(data['deviceId']) : data['deviceId']?.toInt(),
        createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
      );

      if (kDebugMode) {
        print('Sale creata: ${sale.toString()}');
      }

      // Salva nel database locale del server
      final saleId = await _storageService.insertSale(sale);
      if (kDebugMode) {
        print('✅ Vendita inserita nel database con ID: $saleId');
      }

      // Notifica il SalesService locale per aggiornare l'UI
      _onSaleUpdated?.call();
      if (kDebugMode) {
        print('📢 Notificato SalesService locale');
      }

      // Notifica altri dispositivi (se implementato WebSocket)
      _notifyDevices('sale_created', data);

      response.statusCode = HttpStatus.created;
      final responseBody = json.encode({
        'success': true,
        'ticketId': sale.ticketId,
        'message': 'Vendita sincronizzata con successo',
        'saleId': saleId,
      });
      
      response.write(responseBody);
      if (kDebugMode) {
        print('✅ Response vendita inviata: $responseBody');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Errore gestendo richiesta vendita: $e');
        print('Stack trace: $stackTrace');
      }
      
      response.statusCode = HttpStatus.internalServerError;
      response.write(json.encode({
        'success': false,
        'error': 'Errore interno server: $e',
      }));
    }
    
    if (kDebugMode) {
      print('=== FINE GESTIONE RICHIESTA VENDITA ===');
    }
  }

  // Gestisci ottenimento vendite
  Future<void> _handleGetSales(HttpRequest request, HttpResponse response) async {
    final dateParam = request.uri.queryParameters['date'];
    DateTime date = DateTime.now();
    
    if (dateParam != null) {
      date = DateTime.parse(dateParam);
    }

    final sales = await _storageService.getSalesForDate(date);
    final salesData = sales.map((sale) => {
      'ticketId': sale.ticketId,
      'totalAmount': sale.totalAmount,
      'paymentMethod': sale.paymentMethod.name,
      'createdAt': sale.createdAt.toIso8601String(),
      'deviceId': sale.deviceId,
      'items': sale.items.map((item) => {
        'productName': item.productName,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'totalPrice': item.totalPrice,
      }).toList(),
    }).toList();

    response.statusCode = HttpStatus.ok;
    response.write(json.encode(salesData));
  }

  // Gestisci creazione prodotto
  Future<void> _handleCreateProduct(HttpRequest request, HttpResponse response) async {
    if (kDebugMode) {
      print('=== SERVER: RICEVUTA RICHIESTA PRODOTTO ===');
      print('Method: ${request.method}');
      print('Path: ${request.uri.path}');
      print('Headers: ${request.headers}');
    }
    
    try {
      final body = await utf8.decoder.bind(request).join();
      if (kDebugMode) {
        print('Body ricevuto: $body');
      }
      
      final data = json.decode(body);
      if (kDebugMode) {
        print('Dati parsed: $data');
      }

      final product = Product(
        id: data['id'],
        name: data['name'],
        price: data['price']?.toDouble() ?? 0.0,
        category: data['category'],
        isActive: data['is_active'] == 1,
        description: data['description'],
        createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
        updatedAt: data['updated_at'] != null ? DateTime.parse(data['updated_at']) : null,
      );

      if (kDebugMode) {
        print('Prodotto creato: ${product.toString()}');
      }

      if (product.id == null) {
        final insertedId = await _storageService.insertProduct(product);
        if (kDebugMode) {
          print('✅ Prodotto inserito nel database con ID: $insertedId');
        }
      } else {
        await _storageService.updateProduct(product);
        if (kDebugMode) {
          print('✅ Prodotto aggiornato nel database');
        }
      }

      // Notifica il ProductService locale per aggiornare l'UI
      _onProductUpdated?.call();
      if (kDebugMode) {
        print('📢 Notificato ProductService locale');
      }

      // Notifica altri dispositivi
      _notifyDevices('product_updated', data);

      response.statusCode = HttpStatus.ok;
      final responseBody = json.encode({
        'success': true,
        'message': 'Prodotto sincronizzato con successo',
        'productId': product.id,
      });
      
      response.write(responseBody);
      if (kDebugMode) {
        print('✅ Response inviata: $responseBody');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Errore gestendo richiesta prodotto: $e');
        print('Stack trace: $stackTrace');
      }
      
      response.statusCode = HttpStatus.internalServerError;
      response.write(json.encode({
        'success': false,
        'error': 'Errore interno server: $e',
      }));
    }
    
    if (kDebugMode) {
      print('=== FINE GESTIONE RICHIESTA PRODOTTO ===');
    }
  }

  // Gestisci ottenimento prodotti
  Future<void> _handleGetProducts(HttpRequest request, HttpResponse response) async {
    final products = await _storageService.getAllProducts();
    final productsData = products.map((product) => product.toMap()).toList();

    response.statusCode = HttpStatus.ok;
    response.write(json.encode(productsData));
  }

  // Gestisci report consolidato
  Future<void> _handleGetConsolidatedReport(HttpRequest request, HttpResponse response) async {
    final dateParam = request.uri.queryParameters['date'];
    DateTime date = DateTime.now();
    
    if (dateParam != null) {
      date = DateTime.parse(dateParam);
    }

    final sales = await _storageService.getSalesForDate(date);
    final report = DailyReport.fromSales(date, sales);

    // Raggruppa per dispositivo
    final deviceStats = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      final deviceKey = sale.deviceId?.toString() ?? 'unknown';
      if (!deviceStats.containsKey(deviceKey)) {
        deviceStats[deviceKey] = {
          'deviceId': sale.deviceId,
          'totalSales': 0.0,
          'transactionCount': 0,
        };
      }
      deviceStats[deviceKey]!['totalSales'] += sale.totalAmount;
      deviceStats[deviceKey]!['transactionCount']++;
    }

    response.statusCode = HttpStatus.ok;
    response.write(json.encode({
      'date': date.toIso8601String(),
      'totalRevenue': report.totalRevenue,
      'totalTransactions': report.totalTransactions,
      'paymentMethods': {
        'cash': report.totalsByPaymentMethod[PaymentMethod.cash] ?? 0,
        'electronic': report.totalsByPaymentMethod[PaymentMethod.electronic] ?? 0,
      },
      'deviceStats': deviceStats,
      'connectedDevices': _connectedDevices.length,
    }));
  }

  // Gestisci ottenimento dispositivi
  Future<void> _handleGetDevices(HttpRequest request, HttpResponse response) async {
    final devicesData = _connectedDevices.map((device) => {
      'deviceId': device.deviceId,
      'deviceName': device.deviceName,
      'ipAddress': device.ipAddress.address,
      'lastSeen': device.lastSeen.toIso8601String(),
      'isOnline': DateTime.now().difference(device.lastSeen).inMinutes < 5,
    }).toList();

    response.statusCode = HttpStatus.ok;
    response.write(json.encode(devicesData));
  }

  // Gestisci ottenimento vendite raggruppate per dispositivo
  Future<void> _handleGetSalesByDevice(HttpRequest request, HttpResponse response) async {
    final dateParam = request.uri.queryParameters['date'];
    DateTime date = DateTime.now();
    
    if (dateParam != null) {
      date = DateTime.parse(dateParam);
    }

    final sales = await _storageService.getSalesForDate(date);
    
    // Raggruppa vendite per dispositivo
    final Map<String, Map<String, dynamic>> deviceSales = {};
    
    for (final sale in sales) {
      final deviceKey = sale.deviceId?.toString() ?? 'unknown';
      
      if (!deviceSales.containsKey(deviceKey)) {
        // Trova il nome del dispositivo dai dispositivi connessi
        final device = _connectedDevices.cast<ConnectedDevice?>().firstWhere(
          (d) => d?.deviceId == deviceKey,
          orElse: () => null,
        );
        
        deviceSales[deviceKey] = {
          'deviceId': deviceKey,
          'deviceName': device?.deviceName ?? 'Dispositivo Sconosciuto',
          'sales': <Map<String, dynamic>>[],
          'totalRevenue': 0.0,
          'totalTransactions': 0,
          'cashTotal': 0.0,
          'electronicTotal': 0.0,
        };
      }
      
      final saleData = {
        'ticketId': sale.ticketId,
        'totalAmount': sale.totalAmount,
        'paymentMethod': sale.paymentMethod.name,
        'amountPaid': sale.amountPaid,
        'changeGiven': sale.changeGiven,
        'cashierName': sale.cashierName,
        'createdAt': sale.createdAt.toIso8601String(),
        'items': sale.items.map((item) => {
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'totalPrice': item.totalPrice,
        }).toList(),
      };
      
      deviceSales[deviceKey]!['sales'].add(saleData);
      deviceSales[deviceKey]!['totalRevenue'] += sale.totalAmount;
      deviceSales[deviceKey]!['totalTransactions']++;
      
      if (sale.paymentMethod == PaymentMethod.cash) {
        deviceSales[deviceKey]!['cashTotal'] += sale.totalAmount;
      } else {
        deviceSales[deviceKey]!['electronicTotal'] += sale.totalAmount;
      }
    }

    // Calcola totali generali
    final totalRevenue = sales.fold(0.0, (total, sale) => total + sale.totalAmount);
    final totalTransactions = sales.length;
    final cashTotal = sales
        .where((sale) => sale.paymentMethod == PaymentMethod.cash)
        .fold(0.0, (total, sale) => total + sale.totalAmount);
    final electronicTotal = sales
        .where((sale) => sale.paymentMethod == PaymentMethod.electronic)
        .fold(0.0, (total, sale) => total + sale.totalAmount);

    final responseData = {
      'date': date.toIso8601String(),
      'summary': {
        'totalRevenue': totalRevenue,
        'totalTransactions': totalTransactions,
        'cashTotal': cashTotal,
        'electronicTotal': electronicTotal,
        'devicesCount': deviceSales.length,
      },
      'deviceSales': deviceSales.values.toList(),
      'connectedDevices': _connectedDevices.length,
    };

    response.statusCode = HttpStatus.ok;
    response.write(json.encode(responseData));
  }

  // Registra un dispositivo
  void _registerDevice(String deviceId, String deviceName, InternetAddress ipAddress) {
    final existingIndex = _connectedDevices.indexWhere((d) => d.deviceId == deviceId);
    
    if (existingIndex >= 0) {
      // Aggiorna dispositivo esistente
      _connectedDevices[existingIndex] = _connectedDevices[existingIndex].copyWith(
        lastSeen: DateTime.now(),
        ipAddress: ipAddress,
      );
    } else {
      // Nuovo dispositivo
      _connectedDevices.add(ConnectedDevice(
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: ipAddress,
        lastSeen: DateTime.now(),
      ));
      
      if (kDebugMode) {
        print('Nuovo dispositivo connesso: $deviceName ($deviceId) da ${ipAddress.address}');
      }
    }
    
    notifyListeners();
  }

  // Notifica dispositivi (placeholder per WebSocket)
  void _notifyDevices(String eventType, Map<String, dynamic> data) {
    // TODO: Implementare notifiche WebSocket ai dispositivi connessi
    if (kDebugMode) {
      print('Notificando $eventType a ${_connectedDevices.length} dispositivi');
    }
  }

  // Ottieni indirizzo IP locale
  Future<String> _getLocalIPAddress() async {
    if (kIsWeb) {
      return 'localhost'; // Su web non possiamo ottenere l'IP reale
    }
    
    try {
      final interfaces = await NetworkInterface.list();
      
      // Prima cerca interfacce WiFi/Ethernet
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') || 
            interface.name.toLowerCase().contains('eth') ||
            interface.name.toLowerCase().contains('wifi')) {
          for (final address in interface.addresses) {
            if (!address.isLoopback && 
                address.type == InternetAddressType.IPv4 &&
                !address.address.startsWith('169.254')) { // Evita indirizzi link-local
              return address.address;
            }
          }
        }
      }
      
      // Fallback: qualsiasi interfaccia IPv4 non-loopback
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && 
              address.type == InternetAddressType.IPv4 &&
              !address.address.startsWith('169.254')) {
            return address.address;
          }
        }
      }
      
      return 'localhost';
    } catch (e) {
      if (kDebugMode) {
        print('Errore ottenendo IP locale: $e');
      }
      return 'localhost';
    }
  }

  // Salva configurazione server
  Future<void> _saveServerConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_address', _serverAddress ?? '');
      await prefs.setInt('server_port', _serverPort);
      await prefs.setBool('server_enabled', true);
    } catch (e) {
      if (kDebugMode) {
        print('Errore salvando config server: $e');
      }
    }
  }

  // Carica configurazione server
  Future<void> loadServerConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverAddress = prefs.getString('server_address');
      _serverPort = prefs.getInt('server_port') ?? 3000;
      
      // Auto-start se era attivo
      if (prefs.getBool('server_enabled') == true) {
        await startServer();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore caricando config server: $e');
      }
    }
  }

  // Disabilita modalità server
  Future<void> disableServerMode() async {
    await stopServer();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_address');
    await prefs.remove('server_port');
    await prefs.remove('server_enabled');
    
    _serverAddress = null;
  }

  // Registra callback per aggiornamenti prodotti
  void setOnProductUpdatedCallback(Function() callback) {
    _onProductUpdated = callback;
  }

  // Registra callback per aggiornamenti vendite  
  void setOnSaleUpdatedCallback(Function() callback) {
    _onSaleUpdated = callback;
  }

  void _updateStatus(ServerStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}

// Modello per dispositivi connessi
class ConnectedDevice {
  final String deviceId;
  final String deviceName;
  final InternetAddress ipAddress;
  final DateTime lastSeen;

  ConnectedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.lastSeen,
  });

  ConnectedDevice copyWith({
    String? deviceId,
    String? deviceName,
    InternetAddress? ipAddress,
    DateTime? lastSeen,
  }) {
    return ConnectedDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ipAddress: ipAddress ?? this.ipAddress,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  String toString() {
    return 'ConnectedDevice(deviceId: $deviceId, deviceName: $deviceName, ipAddress: ${ipAddress.address})';
  }
}
