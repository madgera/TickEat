import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../models/sale.dart';
import '../models/product.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  SyncService._internal();
  factory SyncService() => _instance;

  // Configurazione
  String? _serverUrl;
  String? _deviceId;
  String? _deviceName;
  WebSocketChannel? _websocket;
  Timer? _heartbeatTimer;
  
  // Stato
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  List<Map<String, dynamic>> _pendingSyncData = [];
  DateTime? _lastSyncTime;

  // Getters
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  String? get serverUrl => _serverUrl;
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Inizializza il servizio di sincronizzazione
  Future<void> initialize() async {
    await _loadSettings();
    if (_serverUrl != null && _deviceId != null) {
      await _connectToServer();
    }
  }

  // Configura server per versione PRO
  Future<bool> configureSuperMode({
    required String serverUrl,
    required String deviceName,
  }) async {
    try {
      _serverUrl = serverUrl;
      _deviceName = deviceName;
      _deviceId = 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';

      // Salva configurazione
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_server_url', serverUrl);
      await prefs.setString('sync_device_name', deviceName);
      await prefs.setString('sync_device_id', _deviceId!);

      // Connetti al server
      await _connectToServer();
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Errore configurazione Super: $e');
      }
      return false;
    }
  }

  // Carica impostazioni salvate
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = prefs.getString('sync_server_url');
      _deviceName = prefs.getString('sync_device_name');
      _deviceId = prefs.getString('sync_device_id');
    } catch (e) {
      if (kDebugMode) {
        print('Errore caricamento impostazioni sync: $e');
      }
    }
  }

  // Connetti al server centrale
  Future<void> _connectToServer() async {
    if (_serverUrl == null || _deviceId == null) return;

    try {
      _updateConnectionStatus(ConnectionStatus.connecting);

      // Test connessione HTTP prima
      final response = await http.get(
        Uri.parse('$_serverUrl/api/health'),
        headers: {'Device-ID': _deviceId!},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server non raggiungibile');
      }

      // Connessione WebSocket per aggiornamenti real-time
      final wsUrl = _serverUrl!.replaceFirst('http', 'ws');
      _websocket = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws?deviceId=$_deviceId'),
      );

      // Ascolta messaggi
      _websocket!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          if (kDebugMode) {
            print('Errore WebSocket: $error');
          }
          _updateConnectionStatus(ConnectionStatus.error);
        },
        onDone: () {
          _updateConnectionStatus(ConnectionStatus.disconnected);
        },
      );

      // Avvia heartbeat
      _startHeartbeat();
      
      _updateConnectionStatus(ConnectionStatus.connected);
      _lastSyncTime = DateTime.now();

      // Sincronizza dati pendenti
      await _syncPendingData();

    } catch (e) {
      if (kDebugMode) {
        print('Errore connessione server: $e');
      }
      _updateConnectionStatus(ConnectionStatus.error);
    }
  }

  void _updateConnectionStatus(ConnectionStatus status) {
    _connectionStatus = status;
    notifyListeners();
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);
      final type = data['type'];

      switch (type) {
        case 'sale_created':
          _handleRemoteSaleCreated(data['payload']);
          break;
        case 'product_updated':
          _handleRemoteProductUpdated(data['payload']);
          break;
        case 'sync_request':
          _handleSyncRequest();
          break;
        default:
          if (kDebugMode) {
            print('Messaggio WebSocket sconosciuto: $type');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore parsing messaggio WebSocket: $e');
      }
    }
  }

  void _handleRemoteSaleCreated(Map<String, dynamic> saleData) {
    // Notifica agli altri servizi che c'è una nuova vendita da un altro dispositivo
    if (kDebugMode) {
      print('Vendita ricevuta da altro dispositivo: ${saleData['ticketId']}');
    }
    // TODO: Aggiornare database locale
    notifyListeners();
  }

  void _handleRemoteProductUpdated(Map<String, dynamic> productData) {
    // Notifica che un prodotto è stato aggiornato da un altro dispositivo
    if (kDebugMode) {
      print('Prodotto aggiornato da altro dispositivo: ${productData['name']}');
    }
    // TODO: Aggiornare database locale
    notifyListeners();
  }

  void _handleSyncRequest() {
    // Il server richiede una sincronizzazione completa
    _syncPendingData();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_websocket != null && _connectionStatus == ConnectionStatus.connected) {
        _websocket!.sink.add(json.encode({
          'type': 'heartbeat',
          'deviceId': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }
    });
  }

  // Sincronizza vendita al server
  Future<void> syncSale(Sale sale) async {
    if (!isConnected) {
      // Aggiungi alla coda per sincronizzazione futura
      _pendingSyncData.add({
        'type': 'sale',
        'data': _saleToSyncData(sale),
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/sales'),
        headers: {
          'Content-Type': 'application/json',
          'Device-ID': _deviceId!,
        },
        body: json.encode(_saleToSyncData(sale)),
      );

      if (response.statusCode == 201) {
        // Notifica altri dispositivi via WebSocket
        if (_websocket != null) {
          _websocket!.sink.add(json.encode({
            'type': 'sale_created',
            'payload': _saleToSyncData(sale),
            'deviceId': _deviceId,
          }));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore sincronizzazione vendita: $e');
      }
      // Aggiungi alla coda per retry
      _pendingSyncData.add({
        'type': 'sale',
        'data': _saleToSyncData(sale),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Sincronizza prodotto al server
  Future<void> syncProduct(Product product) async {
    if (!isConnected) {
      _pendingSyncData.add({
        'type': 'product',
        'data': product.toMap(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/products'),
        headers: {
          'Content-Type': 'application/json',
          'Device-ID': _deviceId!,
        },
        body: json.encode(product.toMap()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Notifica altri dispositivi
        if (_websocket != null) {
          _websocket!.sink.add(json.encode({
            'type': 'product_updated',
            'payload': product.toMap(),
            'deviceId': _deviceId,
          }));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore sincronizzazione prodotto: $e');
      }
    }
  }

  Map<String, dynamic> _saleToSyncData(Sale sale) {
    return {
      'ticketId': sale.ticketId,
      'totalAmount': sale.totalAmount,
      'paymentMethod': sale.paymentMethod.name,
      'amountPaid': sale.amountPaid,
      'changeGiven': sale.changeGiven,
      'cashierName': sale.cashierName,
      'deviceId': _deviceId,
      'createdAt': sale.createdAt.toIso8601String(),
      'items': sale.items.map((item) => {
        'productId': item.productId,
        'productName': item.productName,
        'unitPrice': item.unitPrice,
        'quantity': item.quantity,
        'totalPrice': item.totalPrice,
      }).toList(),
    };
  }

  // Sincronizza dati pendenti
  Future<void> _syncPendingData() async {
    if (!isConnected || _pendingSyncData.isEmpty) return;

    final dataToSync = List<Map<String, dynamic>>.from(_pendingSyncData);
    _pendingSyncData.clear();

    for (final data in dataToSync) {
      try {
        final endpoint = data['type'] == 'sale' ? 'sales' : 'products';
        await http.post(
          Uri.parse('$_serverUrl/api/$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Device-ID': _deviceId!,
          },
          body: json.encode(data['data']),
        );
      } catch (e) {
        // Se fallisce, rimetti in coda
        _pendingSyncData.add(data);
      }
    }

    _lastSyncTime = DateTime.now();
  }

  // Ottieni report consolidato da tutti i dispositivi
  Future<Map<String, dynamic>> getConsolidatedReport(DateTime date) async {
    if (!isConnected) {
      throw Exception('Non connesso al server');
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/reports/consolidated?date=${date.toIso8601String()}'),
        headers: {'Device-ID': _deviceId!},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Errore ottenendo report consolidato');
      }
    } catch (e) {
      throw Exception('Errore comunicazione server: $e');
    }
  }

  // Disconnetti e disabilita modalità Super
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    await _websocket?.sink.close();
    _websocket = null;
    _updateConnectionStatus(ConnectionStatus.disconnected);

    // Rimuovi configurazione
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sync_server_url');
    await prefs.remove('sync_device_name');
    await prefs.remove('sync_device_id');

    _serverUrl = null;
    _deviceName = null;
    _deviceId = null;
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _websocket?.sink.close();
    super.dispose();
  }
}
