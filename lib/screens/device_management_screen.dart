import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/server_service.dart';

class DeviceManagementScreen extends StatelessWidget {
  const DeviceManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Dispositivi'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showServerInfo(context),
            icon: const Icon(Icons.info),
          ),
        ],
      ),
      body: Consumer<ServerService>(
        builder: (context, serverService, child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildServerStatus(serverService),
                const SizedBox(height: 24),
                _buildConnectedDevices(serverService),
                const SizedBox(height: 24),
                _buildServerActions(context, serverService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildServerStatus(ServerService serverService) {
    final isRunning = serverService.isRunning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRunning ? Icons.dns : Icons.dns_outlined,
                  color: isRunning ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server TickEat PRO',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isRunning ? 'In esecuzione' : 'Fermo',
                      style: TextStyle(
                        color: isRunning ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isRunning) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildServerDetails(serverService),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerDetails(ServerService serverService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Indirizzo', '${serverService.serverAddress}:${serverService.serverPort}'),
        _buildDetailRow('Porta', serverService.serverPort.toString()),
        _buildDetailRow('Dispositivi connessi', serverService.connectedDevices.length.toString()),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildConnectedDevices(ServerService serverService) {
    final devices = serverService.connectedDevices;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Dispositivi Connessi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${devices.length}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Nessun dispositivo connesso',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...devices.map((device) => _buildDeviceCard(device)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(ConnectedDevice device) {
    final isOnline = DateTime.now().difference(device.lastSeen).inMinutes < 5;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOnline ? Colors.green : Colors.grey,
          child: Icon(
            isOnline ? Icons.tablet : Icons.tablet_outlined,
            color: Colors.white,
          ),
        ),
        title: Text(device.deviceName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${device.deviceId}'),
            Text('IP: ${device.ipAddress.address}'),
            Text('Ultima attività: ${_formatLastSeen(device.lastSeen)}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOnline ? 'Online' : 'Offline',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildServerActions(BuildContext context, ServerService serverService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Azioni Server',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: serverService.isRunning ? null : () => _startServer(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Avvia Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !serverService.isRunning ? null : () => _stopServer(context),
                    icon: const Icon(Icons.stop),
                    label: const Text('Ferma Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) {
      return 'Ora';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m fa';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h fa';
    } else {
      return '${diff.inDays}g fa';
    }
  }

  Future<void> _startServer(BuildContext context) async {
    final serverService = context.read<ServerService>();
    final success = await serverService.startServer();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Server avviato con successo' : 'Errore avvio server'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _stopServer(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma'),
        content: const Text('Sei sicuro di voler fermare il server? Tutti i dispositivi connessi verranno disconnessi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ferma Server'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final serverService = context.read<ServerService>();
      await serverService.stopServer();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server fermato'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showServerInfo(BuildContext context) {
    final serverService = context.read<ServerService>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informazioni Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stato: ${serverService.isRunning ? "In esecuzione" : "Fermo"}'),
            if (serverService.isRunning) ...[
              Text('Indirizzo: ${serverService.serverAddress}'),
              Text('Porta: ${serverService.serverPort}'),
              Text('Dispositivi: ${serverService.connectedDevices.length}'),
            ],
            const SizedBox(height: 16),
            const Text('Per connettere un client, usa:'),
            if (serverService.isRunning)
              SelectableText(
                'http://${serverService.serverAddress}:${serverService.serverPort}',
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
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
  }
}
