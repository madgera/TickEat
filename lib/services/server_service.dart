import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import '../models/sale.dart';
import '../models/product.dart';
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

  // Getters
  ServerStatus get status => _status;
  String? get serverAddress => _serverAddress;
  int get serverPort => _serverPort;
  List<ConnectedDevice> get connectedDevices => List.unmodifiable(_connectedDevices);
  bool get isRunning => _status == ServerStatus.running;

  // Avvia il server
  Future<bool> startServer({int? port}) async {
    if (_status == ServerStatus.running) return true;

    try {
      _updateStatus(ServerStatus.starting);
      
      _serverPort = port ?? 3000;
      
      // Ottieni l'indirizzo IP locale
      _serverAddress = await _getLocalIPAddress();
      
      // Avvia il server HTTP
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _serverPort);
      
      if (kDebugMode) {
        print('TickEat PRO Server avviato su ${_serverAddress}:${_serverPort}');
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
    final body = await utf8.decoder.bind(request).join();
    final data = json.decode(body);

    // Converti in Sale object
    final saleItems = (data['items'] as List).map((item) => SaleItem(
      productId: item['productId'],
      productName: item['productName'],
      unitPrice: item['unitPrice'],
      quantity: item['quantity'],
      totalPrice: item['totalPrice'],
    )).toList();

    final sale = Sale(
      ticketId: data['ticketId'],
      items: saleItems,
      totalAmount: data['totalAmount'],
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == data['paymentMethod'],
      ),
      amountPaid: data['amountPaid'],
      changeGiven: data['changeGiven'],
      cashierName: data['cashierName'],
      deviceId: data['deviceId'],
      createdAt: DateTime.parse(data['createdAt']),
    );

    // Salva nel database locale del server
    await _storageService.insertSale(sale);

    // Notifica altri dispositivi (se implementato WebSocket)
    _notifyDevices('sale_created', data);

    response.statusCode = HttpStatus.created;
    response.write(json.encode({
      'success': true,
      'ticketId': sale.ticketId,
      'message': 'Vendita sincronizzata con successo',
    }));
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
    final body = await utf8.decoder.bind(request).join();
    final data = json.decode(body);

    final product = Product(
      id: data['id'],
      name: data['name'],
      price: data['price'],
      category: data['category'],
      isActive: data['is_active'] == 1,
      description: data['description'],
    );

    if (product.id == null) {
      await _storageService.insertProduct(product);
    } else {
      await _storageService.updateProduct(product);
    }

    // Notifica altri dispositivi
    _notifyDevices('product_updated', data);

    response.statusCode = HttpStatus.ok;
    response.write(json.encode({
      'success': true,
      'message': 'Prodotto sincronizzato con successo',
    }));
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
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            return address.address;
          }
        }
      }
      return 'localhost';
    } catch (e) {
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
