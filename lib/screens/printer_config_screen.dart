import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import '../services/print_service.dart';
import '../models/sale.dart';
import '../models/fiscal_data.dart';

class PrinterConfigScreen extends StatefulWidget {
  const PrinterConfigScreen({super.key});

  @override
  State<PrinterConfigScreen> createState() => _PrinterConfigScreenState();
}

class _PrinterConfigScreenState extends State<PrinterConfigScreen> {
  final _bluetoothAddressController = TextEditingController();
  final _usbPathController = TextEditingController();
  final _networkAddressController = TextEditingController();
  
  String _selectedConnectionType = 'bluetooth'; // 'bluetooth', 'usb', 'network'
  bool _isTestingConnection = false;
  bool _isScanning = false;
  bool _isPrinting = false;
  
  // Dispositivi scoperti
  final List<DiscoveredDevice> _discoveredDevices = [];
  final List<NetworkPrinterInfo> _networkDevices = [];
  
  // Stream subscriptions per Bluetooth
  StreamSubscription<List<ScanResult>>? _bleScanSubscription;
  StreamSubscription<BluetoothDiscoveryResult>? _sppScanSubscription;
  
  // Network scanning
  bool _isNetworkScanning = false;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _bluetoothAddressController.dispose();
    _usbPathController.dispose();
    _networkAddressController.dispose();
    _bleScanSubscription?.cancel();
    _sppScanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    final printService = PrintService();
    if (printService.printerAddress != null) {
      if (printService.printerType == 'bluetooth') {
        _bluetoothAddressController.text = printService.printerAddress!;
        _selectedConnectionType = 'bluetooth';
      } else if (printService.printerType == 'usb') {
        _usbPathController.text = printService.printerAddress!;
        _selectedConnectionType = 'usb';
      } else if (printService.printerType == 'network') {
        _networkAddressController.text = printService.printerAddress!;
        _selectedConnectionType = 'network';
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurazione Stampante'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _testPrint,
            icon: const Icon(Icons.print),
            tooltip: 'Stampa di Test',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stato attuale stampante
            _buildCurrentStatus(isSmallScreen),
            
            const SizedBox(height: 24),
            
            // Tipo di connessione
            _buildConnectionTypeSection(isSmallScreen),
            
            const SizedBox(height: 24),
            
            // Configurazione Bluetooth
            if (_selectedConnectionType == 'bluetooth') ...[
              _buildBluetoothSection(isSmallScreen),
              const SizedBox(height: 24),
            ],
            
            // Configurazione USB
            if (_selectedConnectionType == 'usb') ...[
              _buildUsbSection(isSmallScreen),
              const SizedBox(height: 24),
            ],
            
            // Configurazione Network
            if (_selectedConnectionType == 'network') ...[
              _buildNetworkSection(isSmallScreen),
              const SizedBox(height: 24),
            ],
            
            // Impostazioni avanzate
            _buildAdvancedSettings(isSmallScreen),
            
            const SizedBox(height: 24),
            
            // Pulsanti azione
            _buildActionButtons(isSmallScreen),
            
            const SizedBox(height: 24),
            
            // Storico stampe
            _buildPrintHistory(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatus(bool isSmallScreen) {
    final printService = PrintService();
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  printService.isConnected ? Icons.print : Icons.print_disabled,
                  color: printService.isConnected ? Colors.green : Colors.red,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
                  'Stato Stampante',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildStatusRow(
              'Stato:',
              printService.isConnected ? 'Connessa' : 'Non connessa',
              printService.isConnected ? Colors.green : Colors.red,
              isSmallScreen,
            ),
            
            if (printService.printerType != null) ...[
              const SizedBox(height: 8),
              _buildStatusRow(
                'Tipo:',
                printService.printerType == 'bluetooth' ? 'Bluetooth' : 'USB',
                Colors.blue,
                isSmallScreen,
              ),
            ],
            
            if (printService.printerAddress != null) ...[
              const SizedBox(height: 8),
              _buildStatusRow(
                'Indirizzo:',
                printService.printerAddress!,
                Colors.grey[700]!,
                isSmallScreen,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isSmallScreen ? 80 : 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionTypeSection(bool isSmallScreen) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo di Connessione',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            isSmallScreen
                ? Column(
                    children: [
                      _buildConnectionTile('bluetooth', Icons.bluetooth, 'Bluetooth', isSmallScreen),
                      const SizedBox(height: 8),
                      _buildConnectionTile('usb', Icons.usb, 'USB/Seriale', isSmallScreen),
                      const SizedBox(height: 8),
                      _buildConnectionTile('network', Icons.wifi, 'Wi-Fi/LAN', isSmallScreen),
                    ],
                  )
                : Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 96) / 3,
                        child: _buildConnectionTile('bluetooth', Icons.bluetooth, 'Bluetooth', isSmallScreen),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 96) / 3,
                        child: _buildConnectionTile('usb', Icons.usb, 'USB/Seriale', isSmallScreen),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 96) / 3,
                        child: _buildConnectionTile('network', Icons.wifi, 'Wi-Fi/LAN', isSmallScreen),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTile(String type, IconData icon, String label, bool isSmallScreen) {
    final isSelected = _selectedConnectionType == type;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedConnectionType = type;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.orange.shade50 : null,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: type,
              groupValue: _selectedConnectionType,
              onChanged: (value) {
                setState(() {
                  _selectedConnectionType = value!;
                });
              },
              activeColor: Colors.orange,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Icon(
              icon,
              color: isSelected ? Colors.orange : Colors.grey[600],
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.orange : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothSection(bool isSmallScreen) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth, color: Colors.blue, size: isSmallScreen ? 20 : 24),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
                  'Configurazione Bluetooth',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Campo indirizzo Bluetooth
            TextFormField(
              controller: _bluetoothAddressController,
              decoration: InputDecoration(
                labelText: 'Indirizzo MAC Bluetooth',
                hintText: '00:11:22:33:44:55',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.bluetooth_connected),
                suffixIcon: IconButton(
                  onPressed: _scanBluetoothDevices,
                  icon: _isScanning 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  tooltip: 'Scansiona Dispositivi',
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f:]')),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Lista dispositivi scoperti
            if (_discoveredDevices.isNotEmpty) ...[
              Text(
                'Dispositivi Trovati:',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...(_discoveredDevices.map((device) => _buildBluetoothDeviceTile(device, isSmallScreen))),
              const SizedBox(height: 16),
            ],
            
            // Informazioni
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: isSmallScreen ? 16 : 18),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Text(
                        Platform.isWindows ? 'Istruzioni Windows' : 'Informazioni',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isWindows
                        ? '• Su Windows, abbina prima la stampante dalle Impostazioni Bluetooth\n'
                          '• Trova l\'indirizzo MAC nelle proprietà del dispositivo\n'
                          '• Formato indirizzo: 00:11:22:33:44:55\n'
                          '• Clicca "Scansiona Dispositivi" per istruzioni dettagliate'
                        : '• Assicurati che la stampante sia accesa e in modalità di abbinamento\n'
                          '• L\'indirizzo MAC ha il formato: 00:11:22:33:44:55\n'
                          '• Usa il pulsante di ricerca per trovare automaticamente le stampanti',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothDeviceTile(DiscoveredDevice device, bool isSmallScreen) {
    final isStrong = (device.rssi ?? -100) > -70;
    final typeLabel = device.type == DeviceType.ble ? 'BLE' : 'SPP';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: isSmallScreen,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              device.type == DeviceType.ble ? Icons.bluetooth : Icons.bluetooth_connected,
              color: isStrong ? Colors.blue : Colors.blue.shade300,
              size: isSmallScreen ? 18 : 22,
            ),
            Text(
              typeLabel,
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.name,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (device.rssi != null) ...[
              Icon(
                Icons.signal_cellular_alt,
                size: 16,
                color: isStrong ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                '${device.rssi}dBm',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          device.address,
          style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
        ),
        trailing: OutlinedButton(
          onPressed: () {
            _bluetoothAddressController.text = device.address;
            setState(() {});
          },
          child: Text(
            'Seleziona',
            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
          ),
        ),
      ),
    );
  }

  Widget _buildUsbSection(bool isSmallScreen) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.usb, color: Colors.green, size: isSmallScreen ? 20 : 24),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
                  'Configurazione USB/Seriale',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Campo percorso USB
            TextFormField(
              controller: _usbPathController,
              decoration: InputDecoration(
                labelText: 'Percorso Dispositivo',
                hintText: defaultTargetPlatform == TargetPlatform.windows 
                    ? 'COM3' 
                    : '/dev/ttyUSB0',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.cable),
                suffixIcon: IconButton(
                  onPressed: _showCommonPaths,
                  icon: const Icon(Icons.list),
                  tooltip: 'Percorsi Comuni',
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Su Windows, aggiungi pulsante per rilevamento automatico porte Bluetooth
            if (Platform.isWindows) ...[
              ElevatedButton.icon(
                onPressed: _detectBluetoothComPorts,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Rileva Porte COM Bluetooth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Informazioni USB
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.green, size: isSmallScreen ? 16 : 18),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Text(
                        'Percorsi Comuni',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    defaultTargetPlatform == TargetPlatform.windows
                        ? '• Windows: COM1, COM2, COM3, ...\n'
                          '• Controlla Gestione Dispositivi per la porta corretta'
                        : '• Linux/Mac: /dev/ttyUSB0, /dev/ttyUSB1\n'
                          '• Serial: /dev/ttyS0, /dev/ttyS1\n'
                          '• Usa "ls /dev/tty*" per vedere i dispositivi disponibili',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSection(bool isSmallScreen) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: Colors.green, size: isSmallScreen ? 20 : 24),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
                  'Configurazione Wi-Fi/LAN',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Campo indirizzo IP
            TextFormField(
              controller: _networkAddressController,
              decoration: InputDecoration(
                labelText: 'Indirizzo IP Stampante',
                hintText: '192.168.1.100:9100',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.router),
                suffixIcon: IconButton(
                  onPressed: _scanNetworkPrinters,
                  icon: _isNetworkScanning 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  tooltip: 'Scansiona Rete',
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.:]')),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Lista stampanti di rete trovate
            if (_networkDevices.isNotEmpty) ...[
              Text(
                'Stampanti di Rete Trovate:',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...(_networkDevices.map((printer) => _buildNetworkDeviceTile(printer, isSmallScreen))),
              const SizedBox(height: 16),
            ],
            
            // Informazioni
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.green, size: isSmallScreen ? 16 : 18),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Text(
                        'Informazioni di Rete',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Assicurati che la stampante sia connessa alla stessa rete Wi-Fi\n'
                    '• Formato indirizzo: IP:PORTA (es. 192.168.1.100:9100)\n'
                    '• La porta standard per stampanti ESC/POS è 9100\n'
                    '• Usa il pulsante di ricerca per trovare automaticamente le stampanti',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(bool isSmallScreen) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impostazioni Avanzate',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Impostazioni di stampa
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Larghezza Carta',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: '58mm',
                        items: const [
                          DropdownMenuItem(value: '58mm', child: Text('58mm')),
                          DropdownMenuItem(value: '80mm', child: Text('80mm')),
                        ],
                        onChanged: (value) {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copie',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: 1,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 copia')),
                          DropdownMenuItem(value: 2, child: Text('2 copie')),
                          DropdownMenuItem(value: 3, child: Text('3 copie')),
                        ],
                        onChanged: (value) {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Opzioni stampante
            CheckboxListTile(
              title: Text(
                'Taglio automatico carta',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
              subtitle: const Text('Taglia automaticamente dopo ogni stampa'),
              value: true,
              onChanged: (value) {},
              activeColor: Colors.orange,
            ),
            
            CheckboxListTile(
              title: Text(
                'Apertura cassetto',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
              subtitle: const Text('Apri il cassetto portamonete dopo ogni vendita'),
              value: false,
              onChanged: (value) {},
              activeColor: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pulsanti principali
        isSmallScreen
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _testConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.link),
                    label: Text(_isTestingConnection ? 'Testando...' : 'Testa Connessione'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _savePrinterSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Salva Configurazione'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _testPrint,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print),
                    label: Text(_isPrinting ? 'Stampando...' : 'Stampa di Test'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _testConnection,
                      icon: _isTestingConnection
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.link),
                      label: Text(_isTestingConnection ? 'Testando...' : 'Testa Connessione'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _savePrinterSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('Salva'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testPrint,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print),
                      label: Text(_isPrinting ? 'Stampando...' : 'Test'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildPrintHistory(bool isSmallScreen) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storico Stampe Recenti',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            FutureBuilder<List<String>>(
              future: PrintService().getPrintHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: isSmallScreen ? 40 : 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nessuna stampa registrata',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final history = snapshot.data!.reversed.take(5).toList();
                
                return Column(
                  children: history.map((entry) {
                    final parts = entry.split('|');
                    if (parts.length >= 3) {
                      final timestamp = DateTime.tryParse(parts[0]);
                      final ticketId = parts[1];
                      final size = parts[2];
                      
                      return ListTile(
                        dense: isSmallScreen,
                        leading: Icon(
                          Icons.receipt,
                          color: Colors.green,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        title: Text(
                          'Biglietto: $ticketId',
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        ),
                        subtitle: Text(
                          timestamp != null
                              ? '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} - $size'
                              : size,
                          style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                        ),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: isSmallScreen ? 16 : 20,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkDeviceTile(NetworkPrinterInfo printer, bool isSmallScreen) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: isSmallScreen,
        leading: Icon(Icons.print, color: Colors.green, size: isSmallScreen ? 20 : 24),
        title: Text(
          '${printer.name} (${printer.model})',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${printer.ip}:${printer.port}',
          style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
        ),
        trailing: OutlinedButton(
          onPressed: () {
            _networkAddressController.text = '${printer.ip}:${printer.port}';
            setState(() {});
          },
          child: Text(
            'Seleziona',
            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
          ),
        ),
      ),
    );
  }

  Future<void> _scanBluetoothDevices() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    try {
      if (Platform.isWindows) {
        // Su Windows usiamo l'approccio manuale
        await _scanWindowsBluetoothDevices();
      } else {
        // Su Android/iOS usiamo i plugin nativi
        if (!await _checkBluetoothPermissions()) {
          _showError('Autorizzazioni Bluetooth necessarie per la scansione');
          return;
        }
        
        // Scansione parallela BLE e SPP
        await Future.wait([
          _scanBLEDevices(),
          _scanSPPDevices(),
        ]);
      }
      
      if (mounted) {
        _showMessage('Scansione completata. Trovati ${_discoveredDevices.length} dispositivi.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Errore durante la scansione: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<bool> _checkBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ];
      
      for (final permission in permissions) {
        final status = await permission.status;
        if (!status.isGranted) {
          final result = await permission.request();
          if (!result.isGranted) {
            return false;
          }
        }
      }
    }
    return true;
  }

  Future<void> _scanBLEDevices() async {
    try {
      // Controlla se Bluetooth è disponibile
      if (await FlutterBluePlus.isSupported == false) {
        return;
      }

      // Avvia scansione BLE
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          final name = result.advertisementData.advName.isNotEmpty 
              ? result.advertisementData.advName 
              : device.platformName.isNotEmpty 
                  ? device.platformName 
                  : 'Dispositivo BLE';
          
          // Filtra dispositivi che potrebbero essere stampanti
          final serviceUuids = result.advertisementData.serviceUuids.map((guid) => guid.toString()).toList();
          if (_isPotentialPrinter(name, serviceUuids)) {
            final discoveredDevice = DiscoveredDevice(
              name: name,
              address: device.remoteId.toString(),
              type: DeviceType.ble,
              rssi: result.rssi,
            );
            
            // Evita duplicati
            if (!_discoveredDevices.any((d) => d.address == discoveredDevice.address)) {
              setState(() {
                _discoveredDevices.add(discoveredDevice);
              });
            }
          }
        }
      });
      
      // Stop automatico dopo timeout
      Future.delayed(const Duration(seconds: 10), () {
        FlutterBluePlus.stopScan();
        _bleScanSubscription?.cancel();
      });
      
    } catch (e) {
      if (kDebugMode) {
        print('Errore scansione BLE: $e');
      }
    }
  }

  Future<void> _scanSPPDevices() async {
    try {
      // Controlla se Bluetooth è abilitato
      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled != true) {
        return;
      }

      // Avvia discovery SPP
      _sppScanSubscription = FlutterBluetoothSerial.instance.startDiscovery().listen(
        (BluetoothDiscoveryResult result) {
          final device = result.device;
          final name = device.name ?? 'Dispositivo SPP';
          
          // Filtra dispositivi che potrebbero essere stampanti
          if (_isPotentialPrinter(name, [])) {
            final discoveredDevice = DiscoveredDevice(
              name: name,
              address: device.address,
              type: DeviceType.spp,
              rssi: result.rssi,
            );
            
            // Evita duplicati
            if (!_discoveredDevices.any((d) => d.address == discoveredDevice.address)) {
              setState(() {
                _discoveredDevices.add(discoveredDevice);
              });
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('Errore discovery SPP: $error');
          }
        },
      );
      
      // Stop automatico dopo 10 secondi
      Future.delayed(const Duration(seconds: 10), () {
        _sppScanSubscription?.cancel();
      });
      
    } catch (e) {
      if (kDebugMode) {
        print('Errore scansione SPP: $e');
      }
    }
  }

  bool _isPotentialPrinter(String name, List<String> serviceUuids) {
    final nameWords = name.toLowerCase();
    final printerKeywords = [
      'print', 'printer', 'thermal', 'pos', 'receipt', 'epson', 'star', 
      'bixolon', 'citizen', 'zebra', 'tsc', 'godex', 'stampante', 'termica'
    ];
    
    // Controlla il nome
    for (final keyword in printerKeywords) {
      if (nameWords.contains(keyword)) {
        return true;
      }
    }
    
    // Controlla service UUIDs comuni per stampanti
    final printerUuids = [
      '49535343-fe7d-4ae5-8fa9-9fafd205e455', // iBeacon Printer Service
      '18f0',  // Battery Service (comune nelle stampanti)
      'fff0',  // Generic Service (usato da molte stampanti)
    ];
    
    for (final uuid in serviceUuids) {
      if (printerUuids.contains(uuid.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }

  Future<void> _scanWindowsBluetoothDevices() async {
    try {
      // Su Windows, suggeriamo alcuni dispositivi comuni e mostriamo come aggiungere manualmente
      _showMessage('Su Windows, aggiungi manualmente l\'indirizzo della stampante Bluetooth.');
      
      // Aggiungi alcuni dispositivi comuni di esempio
      final commonPrinters = [
        DiscoveredDevice(
          name: 'Stampante Bluetooth (Configurazione manuale)',
          address: '00:11:22:33:44:55',
          type: DeviceType.spp,
        ),
      ];
      
      setState(() {
        _discoveredDevices.addAll(commonPrinters);
      });
      
      // Mostra dialog informativo per Windows
      _showWindowsBluetoothHelp();
      
    } catch (e) {
      if (kDebugMode) {
        print('Errore scansione Windows Bluetooth: $e');
      }
    }
  }

  void _showWindowsBluetoothHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Configurazione Bluetooth Windows'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Per configurare una stampante Bluetooth su Windows:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. Vai in Impostazioni Windows → Bluetooth e dispositivi'),
              SizedBox(height: 6),
              Text('2. Assicurati che il Bluetooth sia attivo'),
              SizedBox(height: 6),
              Text('3. Accendi la stampante e mettila in modalità abbinamento'),
              SizedBox(height: 6),
              Text('4. Clicca "Aggiungi dispositivo" → Bluetooth'),
              SizedBox(height: 6),
              Text('5. Seleziona la stampante dall\'elenco'),
              SizedBox(height: 6),
              Text('6. Dopo l\'abbinamento, trova l\'indirizzo MAC nelle proprietà del dispositivo'),
              SizedBox(height: 12),
              Text(
                'Trova l\'indirizzo MAC:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text('• Pannello di controllo → Hardware e suoni → Dispositivi e stampanti'),
              SizedBox(height: 6),
              Text('• Tasto destro sulla stampante → Proprietà → Hardware → Proprietà'),
              SizedBox(height: 6),
              Text('• L\'indirizzo MAC è nel formato 00:11:22:33:44:55'),
              SizedBox(height: 12),
              Text(
                'Porta COM:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text('• Gestione dispositivi → Porte (COM e LPT)'),
              SizedBox(height: 6),
              Text('• Cerca "Standard Serial over Bluetooth link (COMx)"'),
              SizedBox(height: 6),
              Text('• Usa quella porta nel campo USB/Seriale'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCommonBluetoothAddresses();
            },
            child: const Text('Indirizzi Comuni'),
          ),
        ],
      ),
    );
  }

  void _showCommonBluetoothAddresses() {
    final commonAddresses = [
      '00:11:22:33:44:55',
      '00:12:34:56:78:90',
      '00:1A:2B:3C:4D:5E',
      '00:1F:2E:3D:4C:5B',
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Indirizzi MAC Comuni'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: commonAddresses.map((address) => ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(address),
            subtitle: const Text('Formato esempio - sostituisci con quello reale'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _bluetoothAddressController.text = address;
              Navigator.pop(context);
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanNetworkPrinters() async {
    setState(() {
      _isNetworkScanning = true;
      _networkDevices.clear();
    });

    try {
      // Ottieni informazioni di rete
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      
      if (wifiIP == null) {
        _showError('Connessione Wi-Fi non disponibile');
        return;
      }

      // Estrai subnet dalla IP corrente (es. 192.168.1.x)
      final ipParts = wifiIP.split('.');
      if (ipParts.length != 4) {
        _showError('Formato IP non valido');
        return;
      }
      
      final subnet = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';
      
      _showMessage('Scansione rete $subnet.1-254 in corso...');
      
      // Scansiona la rete per stampanti
      final List<Future<void>> scanTasks = [];
      
      for (int i = 1; i <= 254; i++) {
        final ip = '$subnet.$i';
        scanTasks.add(_testNetworkPrinter(ip, 9100)); // Porta standard ESC/POS
      }
      
      // Esegui scansione parallela con limite
      final chunks = <List<Future<void>>>[];
      const chunkSize = 20; // Limita connessioni contemporanee
      
      for (int i = 0; i < scanTasks.length; i += chunkSize) {
        chunks.add(scanTasks.sublist(
          i, 
          i + chunkSize > scanTasks.length ? scanTasks.length : i + chunkSize
        ));
      }
      
      for (final chunk in chunks) {
        await Future.wait(chunk);
        // Piccola pausa tra i chunk
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (mounted) {
        _showMessage('Scansione rete completata. Trovate ${_networkDevices.length} stampanti.');
      }
      
    } catch (e) {
      if (mounted) {
        _showError('Errore durante la scansione di rete: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNetworkScanning = false;
        });
      }
    }
  }

  Future<void> _testNetworkPrinter(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
      
      // Tenta di identificare la stampante
      socket.write('\x1B\x1D\x49\x01'); // ESC GS I n - Request printer ID
      await socket.flush();
      
      await socket.first.timeout(const Duration(seconds: 1));
      await socket.close();
      
      // Se riceviamo una risposta, potrebbe essere una stampante
      final printerInfo = NetworkPrinterInfo(
        ip: ip,
        port: port,
        name: 'Stampante ESC/POS',
        model: 'Rilevata automaticamente',
        isOnline: true,
      );
      
      if (mounted) {
        setState(() {
          _networkDevices.add(printerInfo);
        });
      }
      
    } catch (e) {
      // Connessione fallita - probabilmente non è una stampante
      // Non loggiamo per evitare spam nei log
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    try {
      final printService = PrintService();
      
      // Configura prima la stampante
      bool configured = false;
      if (_selectedConnectionType == 'bluetooth' && _bluetoothAddressController.text.isNotEmpty) {
        configured = await printService.configurePrinter(bluetoothAddress: _bluetoothAddressController.text);
      } else if (_selectedConnectionType == 'usb' && _usbPathController.text.isNotEmpty) {
        configured = await printService.configurePrinter(usbPath: _usbPathController.text);
      } else if (_selectedConnectionType == 'network' && _networkAddressController.text.isNotEmpty) {
        configured = await printService.configurePrinter(networkAddress: _networkAddressController.text);
      }
      
      if (!configured) {
        _showError('Errore nella configurazione della stampante');
        return;
      }
      
      // Testa la connessione
      final connected = await printService.testPrinterConnection();
      
      if (connected) {
        _showMessage('Connessione stabilita con successo!');
      } else {
        _showError('Impossibile connettersi alla stampante');
      }
    } catch (e) {
      _showError('Errore durante il test: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _savePrinterSettings() async {
    try {
      final printService = PrintService();
      bool success = false;
      
      if (_selectedConnectionType == 'bluetooth') {
        if (_bluetoothAddressController.text.isEmpty) {
          _showError('Inserisci l\'indirizzo Bluetooth');
          return;
        }
        success = await printService.configurePrinter(bluetoothAddress: _bluetoothAddressController.text);
      } else if (_selectedConnectionType == 'usb') {
        if (_usbPathController.text.isEmpty) {
          _showError('Inserisci il percorso USB');
          return;
        }
        success = await printService.configurePrinter(usbPath: _usbPathController.text);
      } else if (_selectedConnectionType == 'network') {
        if (_networkAddressController.text.isEmpty) {
          _showError('Inserisci l\'indirizzo di rete');
          return;
        }
        success = await printService.configurePrinter(networkAddress: _networkAddressController.text);
      }
      
      if (success) {
        _showMessage('Configurazione salvata con successo!');
        await _loadCurrentSettings(); // Ricarica lo stato
      } else {
        _showError('Errore nel salvataggio della configurazione');
      }
    } catch (e) {
      _showError('Errore durante il salvataggio: $e');
    }
  }

  Future<void> _testPrint() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      final printService = PrintService();
      
      // Crea una vendita di test
      final testSale = Sale(
        id: 999,
        ticketId: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        items: [
          SaleItem(
            productId: 1,
            productName: 'Prodotto di Test',
            quantity: 1,
            unitPrice: 10.00,
            totalPrice: 10.00,
            vatCalculation: VatCalculation.fromGross(10.00, VatRate.standard),
          ),
          SaleItem(
            productId: 2,
            productName: 'Articolo di Prova',
            quantity: 2,
            unitPrice: 5.50,
            totalPrice: 11.00,
            vatCalculation: VatCalculation.fromGross(11.00, VatRate.standard),
          ),
        ],
        totalAmount: 21.00,
        paymentMethod: PaymentMethod.cash,
        amountPaid: 25.00,
        changeGiven: 4.00,
        createdAt: DateTime.now(),
        cashierName: 'Test',
        deviceId: 1,
      );
      
      final success = await printService.printTicket(
        testSale,
        lotteryCode: 'LTR123456789',
        fiscalDocumentId: 'DOC${DateTime.now().millisecondsSinceEpoch}',
        registryNumber: '${DateTime.now().day.toString().padLeft(2, '0')}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().year}001',
      );
      
      if (success) {
        _showMessage('Stampa di test completata!');
      } else {
        _showError('Errore durante la stampa di test');
      }
    } catch (e) {
      _showError('Errore durante la stampa: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  void _showCommonPaths() async {
    List<String> commonPaths;
    
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Su Windows, prova a rilevare le porte COM Bluetooth
      commonPaths = await _getWindowsComPorts();
      if (commonPaths.isEmpty) {
        commonPaths = ['COM3', 'COM4', 'COM5', 'COM6', 'COM7'];
      }
    } else {
      commonPaths = ['/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyS0', '/dev/ttyS1', '/dev/ttyACM0'];
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Percorsi Comuni'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: commonPaths.map((path) => ListTile(
            title: Text(path),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _usbPathController.text = path;
              Navigator.pop(context);
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _getWindowsComPorts() async {
    try {
      if (!Platform.isWindows) return [];
      
      // Usa PowerShell per rilevare le porte COM Bluetooth
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          r'Get-WmiObject -Class Win32_SerialPort | Where-Object {$_.Description -like "*Bluetooth*"} | Select-Object DeviceID, Description | Format-Table -AutoSize'
        ],
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final lines = output.split('\n');
        final comPorts = <String>[];
        
        for (final line in lines) {
          if (line.contains('COM') && line.contains('Bluetooth')) {
            final match = RegExp(r'(COM\d+)').firstMatch(line);
            if (match != null && match.group(1) != null) {
              comPorts.add(match.group(1)!);
            }
          }
        }
        
        return comPorts;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore rilevamento porte COM: $e');
      }
    }
    
    return [];
  }

  Future<void> _detectBluetoothComPorts() async {
    _showMessage('Rilevamento porte COM Bluetooth...');
    
    try {
      final comPorts = await _getWindowsComPorts();
      
      if (comPorts.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.bluetooth, color: Colors.blue),
                SizedBox(width: 8),
                Text('Porte COM Bluetooth Rilevate'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Seleziona una porta COM per la stampante Bluetooth:'),
                const SizedBox(height: 16),
                ...comPorts.map((port) => ListTile(
                  leading: const Icon(Icons.usb),
                  title: Text(port),
                  subtitle: const Text('Porta COM Bluetooth'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _usbPathController.text = port;
                    Navigator.pop(context);
                    _showMessage('Porta $port selezionata. Usa questa per stampanti Bluetooth abbinate.');
                  },
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        );
      } else {
        _showError('Nessuna porta COM Bluetooth trovata.\n'
                  'Assicurati di aver abbinato la stampante Bluetooth dalle Impostazioni Windows.');
      }
    } catch (e) {
      _showError('Errore durante il rilevamento: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Enumerazioni e classi di supporto
enum DeviceType { ble, spp, network }

class DiscoveredDevice {
  final String name;
  final String address;
  final DeviceType type;
  final int? rssi;
  
  DiscoveredDevice({
    required this.name,
    required this.address,
    required this.type,
    this.rssi,
  });
}

class NetworkPrinterInfo {
  final String ip;
  final int port;
  final String name;
  final String model;
  final bool isOnline;
  
  NetworkPrinterInfo({
    required this.ip,
    required this.port,
    required this.name,
    required this.model,
    required this.isOnline,
  });
}
