import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';

class ProConfigScreen extends StatefulWidget {
  const ProConfigScreen({super.key});

  @override
  State<ProConfigScreen> createState() => _ProConfigScreenState();
}

class _ProConfigScreenState extends State<ProConfigScreen> {
  final _serverUrlController = TextEditingController();
  final _deviceNameController = TextEditingController();
  bool _isConfiguring = false;

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
      body: Consumer<SyncService>(
        builder: (context, syncService, child) {
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
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(syncService.connectionStatus),
                              color: _getStatusColor(syncService.connectionStatus),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Stato: ${_getStatusText(syncService.connectionStatus)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (syncService.deviceId != null) ...[
                          const SizedBox(height: 8),
                          Text('Device ID: ${syncService.deviceId}'),
                        ],
                        if (syncService.lastSyncTime != null) ...[
                          const SizedBox(height: 4),
                          Text('Ultima sincronizzazione: ${_formatDateTime(syncService.lastSyncTime!)}'),
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

                // Configurazione
                if (!syncService.isConnected) ...[
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
                  const SizedBox(height: 24),
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
                          : const Text('Attiva Modalità PRO'),
                    ),
                  ),
                ] else ...[
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
        await context.read<SyncService>().disconnect();
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
