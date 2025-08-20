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
  final List<Map<String, dynamic>> _pendingSyncData = [];
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

  // Test connessione server (utility diagnostica)
  Future<Map<String, dynamic>> testConnection(String serverUrl) async {
    final result = <String, dynamic>{
      'success': false,
      'message': '',
      'details': <String, dynamic>{},
      'suggestions': <String>[],
    };

    try {
      if (kDebugMode) {
        print('Testing connection to: $serverUrl');
      }

      final uri = Uri.parse('$serverUrl/api/health');
      result['details']['url'] = uri.toString();
      result['details']['host'] = uri.host;
      result['details']['port'] = uri.port;

      final stopwatch = Stopwatch()..start();
      
      final response = await http.get(
        uri,
        headers: {
          'Device-ID': 'TEST_DEVICE',
          'Device-Name': 'Test Client',
        },
      ).timeout(const Duration(seconds: 15));

      stopwatch.stop();
      result['details']['responseTime'] = '${stopwatch.elapsedMilliseconds}ms';
      result['details']['statusCode'] = response.statusCode;
      result['details']['responseBody'] = response.body;

      if (response.statusCode == 200) {
        result['success'] = true;
        result['message'] = 'Connessione al server riuscita!';
        
        try {
          final serverInfo = json.decode(response.body);
          result['details']['serverInfo'] = serverInfo;
        } catch (e) {
          // Ignore JSON parsing errors
        }
      } else {
        result['message'] = 'Server risponde ma con status code ${response.statusCode}';
        result['suggestions'].add('Verificare che il server TickEat sia correttamente configurato');
      }

    } catch (e) {
      result['message'] = 'Errore di connessione: $e';
      result['details']['error'] = e.toString();

      if (e.toString().contains('TimeoutException')) {
        result['suggestions'].addAll([
          'Il server potrebbe non essere in ascolto sull\'indirizzo specificato',
          'Verificare che il server sia avviato e in esecuzione',
          'Controllare il firewall di Windows',
          'Provare con http://localhost:3000 se server e client sono sulla stessa macchina',
        ]);
      } else if (e.toString().contains('Connection refused')) {
        result['suggestions'].addAll([
          'Il server non è in ascolto sulla porta specificata',
          'Verificare che il server sia avviato',
          'Controllare che la porta 3000 non sia occupata da altro software',
        ]);
      } else if (e.toString().contains('No route to host')) {
        result['suggestions'].addAll([
          'Problema di rete - host non raggiungibile',
          'Verificare l\'indirizzo IP del server',
          'Controllare la connessione di rete',
        ]);
      } else if (e.toString().contains('SocketException')) {
        result['suggestions'].addAll([
          'Errore di rete - controllare la connessione',
          'Verificare l\'indirizzo IP e la porta',
          'Il server potrebbe essere spento o non raggiungibile',
        ]);
      }
    }

    return result;
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

      if (kDebugMode) {
        print('Tentativo di connessione a: $_serverUrl');
        print('Device ID: $_deviceId');
        print('Device Name: $_deviceName');
      }

      // Test connessione HTTP prima con timeout più lungo e retry
      http.Response? response;
      Exception? lastError;
      
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          if (kDebugMode) {
            print('Tentativo di connessione $attempt/3...');
          }
          
          response = await http.get(
            Uri.parse('$_serverUrl/api/health'),
            headers: {
              'Device-ID': _deviceId!,
              'Device-Name': _deviceName ?? 'Unknown Device',
            },
          ).timeout(const Duration(seconds: 20));
          
          if (response.statusCode == 200) {
            if (kDebugMode) {
              print('Connessione HTTP stabilita (tentativo $attempt)');
              print('Risposta server: ${response.body}');
            }
            break;
          } else {
            throw Exception('Status code: ${response.statusCode}');
          }
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          if (kDebugMode) {
            print('Tentativo $attempt fallito: $e');
          }
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        }
      }

      if (response == null || response.statusCode != 200) {
        throw lastError ?? Exception('Server non raggiungibile dopo 3 tentativi');
      }

      // Connessione WebSocket per aggiornamenti real-time (opzionale)
      try {
        final wsUrl = _serverUrl!.replaceFirst('http', 'ws');
        _websocket = WebSocketChannel.connect(
          Uri.parse('$wsUrl/ws?deviceId=$_deviceId'),
        );

        // Ascolta messaggi
        _websocket!.stream.listen(
          _handleWebSocketMessage,
          onError: (error) {
            if (kDebugMode) {
              print('Errore WebSocket (non critico): $error');
            }
            // Non cambiare lo stato di connessione per errori WebSocket
            // Il client può funzionare solo con HTTP
          },
          onDone: () {
            if (kDebugMode) {
              print('WebSocket disconnesso');
            }
          },
        );

        if (kDebugMode) {
          print('WebSocket connesso');
        }
      } catch (e) {
        if (kDebugMode) {
          print('WebSocket non disponibile (continuando solo con HTTP): $e');
        }
        // Continua senza WebSocket, il client può funzionare solo con HTTP
      }

      // Avvia heartbeat
      _startHeartbeat();
      
      _updateConnectionStatus(ConnectionStatus.connected);
      _lastSyncTime = DateTime.now();

      if (kDebugMode) {
        print('Connessione al server completata con successo');
      }

      // Sincronizza dati pendenti
      await _syncPendingData();

    } catch (e) {
      if (kDebugMode) {
        print('Errore connessione server: $e');
        
        // Diagnostica aggiuntiva
        if (e.toString().contains('TimeoutException')) {
          print('DIAGNOSTICA: Il server potrebbe non essere in ascolto su $_serverUrl');
          print('SUGGERIMENTI:');
          print('1. Verificare che il server sia avviato');
          print('2. Controllare l\'indirizzo IP e la porta');
          print('3. Verificare il firewall di Windows');
          print('4. Provare con http://localhost:3000 se in locale');
        } else if (e.toString().contains('Connection refused')) {
          print('DIAGNOSTICA: Connessione rifiutata - server non in ascolto');
        } else if (e.toString().contains('No route to host')) {
          print('DIAGNOSTICA: Host non raggiungibile - problema di rete');
        }
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
