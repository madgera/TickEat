import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';
import '../services/server_service.dart';

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
    final syncService = context.read<SyncService>();
    if (syncService.serverUrl != null) {
      _serverUrlController.text = syncService.serverUrl!;
    }
    if (syncService.deviceName != null) {
      _deviceNameController.text = syncService.deviceName!;
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
      body: Consumer2<SyncService, ServerService>(
        builder: (context, syncService, serverService, child) {
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
                        // Stato Client
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(syncService.connectionStatus),
                              color: _getStatusColor(syncService.connectionStatus),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Client: ${_getStatusText(syncService.connectionStatus)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (syncService.deviceId != null) ...[
                          const SizedBox(height: 8),
                          Text('Device ID: ${syncService.deviceId}'),
                        ],
                        
                        const SizedBox(height: 16),
                        const Divider(),
                        
                        // Stato Server
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
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Informazioni modalità PRO
                const Text(
                  'Modalità PRO - Multi-Dispositivo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La modalità PRO consente di collegare più dispositivi per condividere dati in tempo reale. '
                  'È necessario un server centrale per coordinare le operazioni.',
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 24),

                // Selezione modalità
                const Text(
                  'Modalità Dispositivo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Client', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Si connette a un server', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        value: 'client',
                        groupValue: _selectedMode,
                        onChanged: (value) {
                          setState(() {
                            _selectedMode = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Server', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Diventa il server centrale', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
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

                const SizedBox(height: 24),

                // Configurazione Client
                if (_selectedMode == 'client' && !syncService.isConnected) ...[
                  TextField(
                    controller: _serverUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL Server *',
                      hintText: 'http://192.168.1.100:3000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cloud),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _deviceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome Dispositivo *',
                      hintText: 'Cassa 1',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tablet),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Test Connection Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isConfiguring ? null : _testConnection,
                      icon: const Icon(Icons.wifi_find),
                      label: const Text('Testa Connessione'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isConfiguring ? null : _configureProMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isConfiguring
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Configurando...'),
                              ],
                            )
                          : const Text('Connetti come Client'),
                    ),
                  ),
                ],

                // Configurazione Server
                if (_selectedMode == 'server' && !serverService.isRunning) ...[
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
                  TextField(
                    controller: _deviceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome Server *',
                      hintText: 'Server Principale',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _serverPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Porta Server',
                      hintText: '3000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.router),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (kIsWeb || _isConfiguring) ? null : _startServerMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kIsWeb ? Colors.grey : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isConfiguring
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Avviando Server...'),
                              ],
                            )
                          : Text(kIsWeb ? 'Non Supportato su Web' : 'Avvia come Server'),
                    ),
                  ),
                ],

                // Stato attivo
                if (syncService.isConnected || serverService.isRunning) ...[
                  // Dispositivo già configurato
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Modalità PRO Attiva',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Server: ${syncService.serverUrl}'),
                        Text('Dispositivo: ${syncService.deviceName}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _disconnectProMode,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Disattiva Modalità PRO'),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Funzionalità PRO
                const Text(
                  'Funzionalità Modalità PRO',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  Icons.sync,
                  'Sincronizzazione Tempo Reale',
                  'Vendite e prodotti sincronizzati automaticamente tra tutti i dispositivi',
                ),
                _buildFeatureCard(
                  Icons.analytics,
                  'Report Consolidati',
                  'Visualizza statistiche unificate da tutte le casse',
                ),
                _buildFeatureCard(
                  Icons.devices,
                  'Gestione Multi-Cassa',
                  'Identifica quale cassa ha effettuato ogni vendita',
                ),
                _buildFeatureCard(
                  Icons.backup,
                  'Backup Automatico',
                  'Dati salvati automaticamente sul server centrale',
                ),

                const SizedBox(height: 32),

                // Requisiti tecnici
                ExpansionTile(
                  title: const Text('Requisiti Tecnici'),
                  leading: const Icon(Icons.info_outline),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Server centrale con TickEat PRO Server installato'),
                          Text('• Connessione WiFi stabile tra tutti i dispositivi'),
                          Text('• Stesso segmento di rete (consigliato)'),
                          Text('• Porta 3000 aperta sul server'),
                          Text('• Almeno 1GB RAM disponibile sul server'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue[700]),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }

  IconData _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Icons.cloud_done;
      case ConnectionStatus.connecting:
        return Icons.cloud_sync;
      case ConnectionStatus.error:
        return Icons.cloud_off;
      case ConnectionStatus.disconnected:
        return Icons.cloud_outlined;
    }
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.error:
        return Colors.red;
      case ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  String _getStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Connesso';
      case ConnectionStatus.connecting:
        return 'Connessione in corso...';
      case ConnectionStatus.error:
        return 'Errore di connessione';
      case ConnectionStatus.disconnected:
        return 'Disconnesso';
    }
  }

  // Metodi per lo stato del server
  IconData _getServerStatusIcon(ServerStatus status) {
    switch (status) {
      case ServerStatus.running:
        return Icons.dns;
      case ServerStatus.starting:
        return Icons.sync;
      case ServerStatus.error:
        return Icons.error;
      case ServerStatus.stopped:
        return Icons.dns_outlined;
    }
  }

  Color _getServerStatusColor(ServerStatus status) {
    switch (status) {
      case ServerStatus.running:
        return Colors.green;
      case ServerStatus.starting:
        return Colors.orange;
      case ServerStatus.error:
        return Colors.red;
      case ServerStatus.stopped:
        return Colors.grey;
    }
  }

  String _getServerStatusText(ServerStatus status) {
    switch (status) {
      case ServerStatus.running:
        return 'In esecuzione';
      case ServerStatus.starting:
        return 'Avvio in corso...';
      case ServerStatus.error:
        return 'Errore';
      case ServerStatus.stopped:
        return 'Fermo';
    }
  }



  Future<void> _startServerMode() async {
    if (_deviceNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il nome del server')),
      );
      return;
    }

    setState(() {
      _isConfiguring = true;
    });

    try {
      final serverService = context.read<ServerService>();
      final port = int.tryParse(_serverPortController.text) ?? 3000;
      
      final success = await serverService.startServer(port: port);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server avviato su ${serverService.serverAddress}:${serverService.serverPort}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore durante l\'avvio del server. Verifica la porta.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (_serverUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci l\'URL del server')),
      );
      return;
    }

    setState(() {
      _isConfiguring = true;
    });

    try {
      final syncService = context.read<SyncService>();
      final result = await syncService.testConnection(_serverUrlController.text.trim());

      if (mounted) {
        _showConnectionTestResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  void _showConnectionTestResult(Map<String, dynamic> result) {
    final isSuccess = result['success'] as bool;
    final message = result['message'] as String;
    final details = result['details'] as Map<String, dynamic>;
    final suggestions = result['suggestions'] as List<dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isSuccess ? 'Test Riuscito' : 'Test Fallito'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              if (details.isNotEmpty) ...[
                const Text('Dettagli:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...details.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('${entry.key}: ${entry.value}'),
                )).toList(),
                const SizedBox(height: 16),
              ],
              
              if (suggestions.isNotEmpty) ...[
                const Text('Suggerimenti:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...suggestions.map((suggestion) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• $suggestion'),
                )).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
          if (isSuccess)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _configureProMode();
              },
              child: const Text('Procedi alla Connessione'),
            ),
        ],
      ),
    );
  }

  Future<void> _configureProMode() async {
    if (_serverUrlController.text.trim().isEmpty || _deviceNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila tutti i campi obbligatori')),
      );
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

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modalità PRO attivata con successo!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore durante l\'attivazione. Verifica i dati inseriti.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  Future<void> _disconnectProMode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disattiva Modalità PRO'),
        content: const Text(
          'Sei sicuro di voler disattivare la modalità PRO?\n\n'
          'Il dispositivo tornerà a funzionare in modalità BASE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disattiva', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final syncService = context.read<SyncService>();
        final serverService = context.read<ServerService>();
        
        // Disconnetti client
        if (syncService.isConnected) {
          await syncService.disconnect();
        }
        
        // Ferma server
        if (serverService.isRunning) {
          await serverService.stopServer();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Modalità PRO disattivata')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
