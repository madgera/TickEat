import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sale.dart';

class PrintService extends ChangeNotifier {
  static final PrintService _instance = PrintService._internal();
  PrintService._internal();
  factory PrintService() => _instance;

  // Configurazione stampante
  String? _printerAddress;
  String? _printerType; // 'bluetooth' o 'usb'
  bool _isConnected = false;
  
  String generateTicketContent(Sale sale) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    // Header
    buffer.writeln('================================');
    buffer.writeln('           TICKEAT');
    buffer.writeln('           RECEIPT');
    buffer.writeln('================================');
    buffer.writeln('');
    
    // Informazioni biglietto
    buffer.writeln('Biglietto: ${sale.ticketId}');
    buffer.writeln('Data: ${dateFormat.format(sale.createdAt)}');
    if (sale.cashierName != null) {
      buffer.writeln('Operatore: ${sale.cashierName}');
    }
    if (sale.deviceId != null) {
      buffer.writeln('Cassa: ${sale.deviceId}');
    }
    buffer.writeln('');
    buffer.writeln('================================');
    
    // Articoli
    for (final item in sale.items) {
      buffer.writeln(item.productName);
      buffer.writeln('  ${item.quantity} x €${item.unitPrice.toStringAsFixed(2)} = €${item.totalPrice.toStringAsFixed(2)}');
    }
    
    buffer.writeln('--------------------------------');
    buffer.writeln('TOTALE: €${sale.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('');
    
    // Informazioni pagamento
    final paymentMethodText = sale.paymentMethod == PaymentMethod.cash ? 'CONTANTI' : 'ELETTRONICO';
    buffer.writeln('Pagamento: $paymentMethodText');
    
    if (sale.paymentMethod == PaymentMethod.cash) {
      if (sale.amountPaid != null) {
        buffer.writeln('Ricevuto: €${sale.amountPaid!.toStringAsFixed(2)}');
      }
      if (sale.changeGiven != null && sale.changeGiven! > 0) {
        buffer.writeln('Resto: €${sale.changeGiven!.toStringAsFixed(2)}');
      }
    }
    
    buffer.writeln('');
    buffer.writeln('================================');
    buffer.writeln('      Grazie per la visita!');
    buffer.writeln('================================');
    buffer.writeln('');
    buffer.writeln('');
    buffer.writeln('');
    
    return buffer.toString();
  }

  Future<bool> printTicket(Sale sale) async {
    try {
      final ticketContent = generateTicketContent(sale);
      
      // Debug: sempre stampa nel console
      if (kDebugMode) {
        print('=== STAMPA BIGLIETTO ===');
        print(ticketContent);
        print('========================');
      }
      
      // Simulazione stampa fisica
      await _simulatePrint(ticketContent);
      
      // Salva nelle preferenze per storico
      await _saveToHistory(sale.ticketId, ticketContent);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Errore durante la stampa: $e');
      }
      return false;
    }
  }

  Future<void> _simulatePrint(String content) async {
    // Simula il tempo di stampa
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_isConnected && _printerAddress != null) {
      // Qui verrebbe implementata la stampa reale
      if (kDebugMode) {
        print('Stampando su $_printerType: $_printerAddress');
      }
    } else {
      if (kDebugMode) {
        print('Stampante non configurata - stampa simulata');
      }
    }
  }

  Future<void> _saveToHistory(String ticketId, String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('print_history') ?? [];
      
      final timestamp = DateTime.now().toIso8601String();
      history.add('$timestamp|$ticketId|${content.length} caratteri');
      
      // Mantieni solo gli ultimi 100 biglietti
      if (history.length > 100) {
        history.removeAt(0);
      }
      
      await prefs.setStringList('print_history', history);
    } catch (e) {
      if (kDebugMode) {
        print('Errore salvando storico stampa: $e');
      }
    }
  }

  // Metodo per testare la connessione della stampante
  Future<bool> testPrinterConnection() async {
    try {
      await _loadPrinterSettings();
      
      if (_printerAddress == null) {
        return false;
      }
      
      // Simula test connessione
      await Future.delayed(const Duration(milliseconds: 1000));
      
      _isConnected = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // Configura stampante
  Future<bool> configurePrinter({
    String? bluetoothAddress,
    String? usbPath,
    String? networkAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (bluetoothAddress != null) {
        _printerAddress = bluetoothAddress;
        _printerType = 'bluetooth';
        await prefs.setString('printer_address', bluetoothAddress);
        await prefs.setString('printer_type', 'bluetooth');
      } else if (usbPath != null) {
        _printerAddress = usbPath;
        _printerType = 'usb';
        await prefs.setString('printer_address', usbPath);
        await prefs.setString('printer_type', 'usb');
      } else if (networkAddress != null) {
        _printerAddress = networkAddress;
        _printerType = 'network';
        await prefs.setString('printer_address', networkAddress);
        await prefs.setString('printer_type', 'network');
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadPrinterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _printerAddress = prefs.getString('printer_address');
      _printerType = prefs.getString('printer_type');
    } catch (e) {
      if (kDebugMode) {
        print('Errore caricando impostazioni stampante: $e');
      }
    }
  }

  // Ottieni storico stampe
  Future<List<String>> getPrintHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('print_history') ?? [];
    } catch (e) {
      return [];
    }
  }

  // Stato stampante
  bool get isConnected => _isConnected;
  String? get printerAddress => _printerAddress;
  String? get printerType => _printerType;
}
