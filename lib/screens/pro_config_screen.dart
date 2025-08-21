import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/build_config.dart';
import '../services/sync_service.dart';
import '../services/server_service.dart';
import '../widgets/conditional_consumer.dart';

class ProConfigScreen extends StatefulWidget {
  const ProConfigScreen({super.key});

  @override
  State<ProConfigScreen> createState() => _ProConfigScreenState();
}

class _ProConfigScreenState extends State<ProConfigScreen> {
  final _serverUrlController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _serverPortController = TextEditingController(text: '3000');
  bool _isConfiguring = false;
  String _selectedMode = 'client'; // 'client' o 'server'

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    if (BuildConfig.shouldInitializeSyncService) {
      try {
        final syncService = context.read<SyncService>();
        if (syncService.serverUrl != null) {
          _serverUrlController.text = syncService.serverUrl!;
        }
        if (syncService.deviceName != null) {
          _deviceNameController.text = syncService.deviceName!;
        }
      } catch (e) {
        // SyncService non disponibile
      }
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _deviceNameController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurazione PRO'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (BuildConfig.shouldInitializeServerService) {
      // PRO SERVER mode - ha entrambi i servizi
      return Consumer2<SyncService, ServerService>(
        builder: (context, syncService, serverService, child) {
          return _buildContent(syncService, serverService);
        },
      );
    } else {
      // PRO CLIENT mode - solo SyncService
      return ConditionalSyncConsumer(
        builder: (context, syncService, child) {
          return _buildContent(syncService, null);
        },
        fallback: const Center(
          child: Text('Servizio di sincronizzazione non disponibile'),
        ),
      );
    }
  }

  Widget _buildContent(SyncService syncService, ServerService? serverService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stato attuale
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stato Attuale',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stato Client
                  Row(
                    children: [
                      Icon(
                        syncService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: syncService.isConnected ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Client: ${syncService.isConnected ? 'Connesso' : 'Disconnesso'}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (syncService.isConnected) ...[
                    const SizedBox(height: 8),
                    Text('Server: ${syncService.serverUrl}'),
                    Text('Dispositivo: ${syncService.deviceName}'),
                  ],
                  
                  // Stato Server (solo in modalità PRO SERVER)
                  if (serverService != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    Row(
                      children: [
                        Icon(
                          _getServerStatusIcon(serverService.status),
                          color: _getServerStatusColor(serverService.status),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Server: ${_getServerStatusText(serverService.status)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (serverService.isRunning) ...[
                      const SizedBox(height: 8),
                      Text('Indirizzo: ${serverService.serverAddress}:${serverService.serverPort}'),
                      Text('Dispositivi connessi: ${serverService.connectedDevices.length}'),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Selezione modalità
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Modalità Operativa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Client'),
                          subtitle: const Text('Connetti a server esistente'),
                          value: 'client',
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() {
                              _selectedMode = value!;
                            });
                          },
                        ),
                      ),
                      if (BuildConfig.shouldInitializeServerService)
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Server'),
                            subtitle: const Text('Avvia server locale'),
                            value: 'server',
                            groupValue: _selectedMode,
                            onChanged: (value) {
                              setState(() {
                                _selectedMode = value!;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Configurazione Client
          if (_selectedMode == 'client') ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configurazione Client',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL Server *',
                        hintText: 'http://192.168.1.100:3000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      enabled: !_isConfiguring,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _deviceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Dispositivo *',
                        hintText: 'Cassa 1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.devices),
                      ),
                      enabled: !_isConfiguring,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isConfiguring ? null : _testConnection,
                            icon: const Icon(Icons.network_check),
                            label: const Text('Testa Connessione'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isConfiguring ? null : _connectAsClient,
                            icon: _isConfiguring
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: _isConfiguring
                                ? const Text('Connessione...')
                                : const Text('Connetti come Client'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Configurazione Server (solo se supportato)
          if (_selectedMode == 'server' && BuildConfig.shouldInitializeServerService && serverService != null && !serverService.isRunning) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configurazione Server',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Avviso per piattaforme non supportate
                    if (kIsWeb) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'La modalità server non è supportata su browser web. '
                                'Usa l\'app su dispositivo mobile, tablet o desktop.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    TextFormField(
                      controller: _deviceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Server *',
                        hintText: 'Server Principale',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.dns),
                      ),
                      enabled: !_isConfiguring,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _serverPortController,
                      decoration: const InputDecoration(
                        labelText: 'Porta Server',
                        hintText: '3000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings_ethernet),
                      ),
                      enabled: !_isConfiguring,
                      keyboardType: TextInputType.number,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (kIsWeb || _isConfiguring) ? null : _startServerMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kIsWeb ? Colors.grey : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: _isConfiguring
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: _isConfiguring
                            ? const Text('Avvio server...')
                            : const Text('Avvia Server'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Stato attivo
          if (syncService.isConnected || (serverService?.isRunning ?? false)) ...[
            // Dispositivo già configurato
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Modalità PRO Attiva',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _disconnectFromPro,
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('Disattiva Modalità PRO'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Informazioni
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informazioni',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Modalità Client: Connetti questo dispositivo a un server centrale per la sincronizzazione',
                  ),
                  if (BuildConfig.shouldInitializeServerService)
                    const Text(
                      '• Modalità Server: Trasforma questo dispositivo nel server centrale per altri client',
                    ),
                  const Text(
                    '• La sincronizzazione include prodotti, vendite e configurazioni',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    final serverUrl = _serverUrlController.text.trim();
    if (serverUrl.isEmpty) {
      _showError('Inserisci l\'URL del server');
      return;
    }

    setState(() {
      _isConfiguring = true;
    });

    try {
      final syncService = context.read<SyncService>();
      final result = await syncService.testConnection(serverUrl);
      
      if (result['success']) {
        _showSuccess('Connessione riuscita! Server raggiungibile.');
      } else {
        _showConnectionError(result);
      }
    } catch (e) {
      _showError('Errore durante il test: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  Future<void> _connectAsClient() async {
    if (_serverUrlController.text.trim().isEmpty || _deviceNameController.text.trim().isEmpty) {
      _showError('Compila tutti i campi obbligatori');
      return;
    }

    setState(() {
      _isConfiguring = true;
    });

    try {
      final syncService = context.read<SyncService>();
      final success = await syncService.configureSuperMode(
        serverUrl: _serverUrlController.text.trim(),
        deviceName: _deviceNameController.text.trim(),
      );

      if (success && mounted) {
        _showSuccess('Connesso al server con successo!');
      } else if (mounted) {
        _showError('Impossibile connettersi al server. Verifica l\'URL e riprova.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Errore durante la connessione: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  Future<void> _startServerMode() async {
    if (_deviceNameController.text.trim().isEmpty) {
      _showError('Inserisci il nome del server');
      return;
    }

    setState(() {
      _isConfiguring = true;
    });

    try {
      if (!BuildConfig.shouldInitializeServerService) {
        _showError('Server non disponibile in questa modalità');
        return;
      }
      
      final serverService = context.read<ServerService>();
      final port = int.tryParse(_serverPortController.text) ?? 3000;
      
      final success = await serverService.startServer(port: port);

      if (success) {
        if (mounted) {
          _showSuccess('Server avviato su ${serverService.serverAddress}:${serverService.serverPort}');
        }
      } else {
        if (mounted) {
          _showError('Errore durante l\'avvio del server. Verifica la porta.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Errore durante l\'avvio del server: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  Future<void> _disconnectFromPro() async {
    setState(() {
      _isConfiguring = true;
    });

    try {
      final syncService = context.read<SyncService>();
      final serverService = BuildConfig.shouldInitializeServerService 
          ? context.read<ServerService>() 
          : null;

      // Disconnetti client
      if (syncService.isConnected) {
        await syncService.disconnect();
      }
      
      // Ferma server (se disponibile)
      if (serverService != null && serverService.isRunning) {
        await serverService.stopServer();
      }
      
      if (mounted) {
        _showSuccess('Modalità PRO disattivata');
      }
    } catch (e) {
      if (mounted) {
        _showError('Errore durante la disconnessione: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showConnectionError(Map<String, dynamic> result) {
    final message = result['message'] as String;
    final suggestions = result['suggestions'] as List<String>;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Errore di Connessione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Suggerimenti:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...suggestions.map((s) => Text('• $s')),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  IconData _getServerStatusIcon(dynamic status) {
    switch (status.toString()) {
      case 'running':
        return Icons.cloud_done;
      case 'stopped':
        return Icons.cloud_off;
      case 'error':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _getServerStatusColor(dynamic status) {
    switch (status.toString()) {
      case 'running':
        return Colors.green;
      case 'stopped':
        return Colors.grey;
      case 'error':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getServerStatusText(dynamic status) {
    switch (status.toString()) {
      case 'running':
        return 'In esecuzione';
      case 'stopped':
        return 'Fermo';
      case 'error':
        return 'Errore';
      default:
        return 'Sconosciuto';
    }
  }
}