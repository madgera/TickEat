import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/build_config.dart';
import '../services/print_service.dart';
import '../services/sync_service.dart';
import '../services/fiscal_service.dart';
import 'pro_config_screen.dart';
import 'printer_config_screen.dart';
import 'fiscal_status_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const _SectionHeader('Informazioni App'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('TickEat'),
            subtitle: Text('Versione 1.0.0 - ${_getAppDescription()}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getModeColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getModeLabel(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          
          const Divider(),
          const _SectionHeader('Conformità Fiscale'),
          Consumer<FiscalService>(
            builder: (context, fiscalService, child) {
              return ListTile(
                leading: Icon(
                  fiscalService.isConfigured ? Icons.security : Icons.warning,
                  color: fiscalService.isConfigured ? Colors.green : Colors.orange,
                ),
                title: const Text('Configurazione Fiscale'),
                subtitle: Text(
                  fiscalService.isConfigured 
                      ? 'Sistema conforme RT - Agenzia delle Entrate'
                      : 'Configurazione richiesta per conformità fiscale',
                ),
                trailing: fiscalService.isConfigured 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FiscalStatusScreen()),
                ),
              );
            },
          ),
          
          const Divider(),
          const _SectionHeader('Stampa'),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Test Stampante'),
            subtitle: const Text('Verifica connessione stampante termica'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _testPrinter(context),
          ),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Configura Stampante'),
            subtitle: const Text('Impostazioni stampante Bluetooth/USB'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrinterConfigScreen()),
            ),
          ),
          
          // Sezione PRO solo se non in modalità BASE
          if (BuildConfig.showProFeatures) ...[
            const Divider(),
            const _SectionHeader('Configurazione PRO'),
            Consumer<SyncService>(
              builder: (context, syncService, child) {
                return ListTile(
                  leading: Icon(
                    syncService.isConnected ? Icons.cloud_done : Icons.cloud_upload,
                    color: syncService.isConnected ? Colors.green : null,
                  ),
                  title: Text(syncService.isConnected ? 'Modalità PRO Attiva' : 'Configura PRO'),
                  subtitle: Text(
                    syncService.isConnected 
                        ? 'Multi-dispositivo sincronizzato'
                        : 'Multi-dispositivo e sincronizzazione',
                  ),
                  trailing: syncService.isConnected 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProConfigScreen()),
                  ),
                );
              },
            ),
            
            // Configurazione Stampante
            Consumer<PrintService>(
              builder: (context, printService, child) {
                return ListTile(
                  leading: Icon(
                    printService.isConnected ? Icons.print : Icons.print_disabled,
                    color: printService.isConnected ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Configurazione Stampante'),
                  subtitle: Text(
                    printService.isConnected 
                        ? 'Stampante connessa (${printService.printerType})'
                        : 'Configurazione stampante termica',
                  ),
                  trailing: printService.isConnected 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PrinterConfigScreen()),
                  ),
                );
              },
            ),
          ] else ...[
            const Divider(),
            const _SectionHeader('Versione PRO'),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Aggiorna a PRO'),
              subtitle: const Text('Multi-dispositivo e sincronizzazione'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showProUpgrade(context),
            ),
          ],
          
          const Divider(),
          const _SectionHeader('Supporto'),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Guida'),
            subtitle: const Text('Come utilizzare TickEat'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHelp(context),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Segnala Problema'),
            subtitle: const Text('Aiutaci a migliorare l\'app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _reportIssue(context),
          ),
          
          const SizedBox(height: 32),
          const Center(
            child: Text(
              '© 2024 TickEat - Sviluppato per sagre e feste',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _testPrinter(BuildContext context) async {
    final printService = PrintService();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Test stampante in corso...'),
          ],
        ),
      ),
    );

    final success = await printService.testPrinterConnection();
    
    if (context.mounted) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(success ? 'Test Riuscito' : 'Test Fallito'),
          content: Text(
            success 
                ? 'La stampante è collegata e funzionante'
                : 'Impossibile connettersi alla stampante.\nVerifica che sia accesa e collegata.',
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
  }



  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guida Rapida'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Come utilizzare TickEat:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Aggiungi prodotti nella sezione "Prodotti"'),
              Text('2. Seleziona prodotti dal menu principale'),
              Text('3. Verifica il carrello'),
              Text('4. Procedi al pagamento'),
              Text('5. Stampa il biglietto'),
              SizedBox(height: 16),
              Text(
                'Report:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Visualizza vendite giornaliere'),
              Text('• Esporta dati in CSV/PDF'),
              Text('• Reset dati a fine giornata'),
            ],
          ),
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

  void _reportIssue(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Segnala Problema'),
        content: const Text(
          'Per segnalare un problema o richiedere assistenza, '
          'contatta il supporto tecnico con una descrizione dettagliata del problema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grazie per il feedback!')),
              );
            },
            child: const Text('Invia'),
          ),
        ],
      ),
    );
  }

  String _getAppDescription() {
    switch (BuildConfig.appMode) {
      case AppMode.base:
        return 'Registratore di Cassa per Eventi';
      case AppMode.proClient:
        return 'Client Multi-Dispositivo';
      case AppMode.proServer:
        return 'Server Multi-Dispositivo';
    }
  }

  String _getModeLabel() {
    switch (BuildConfig.appMode) {
      case AppMode.base:
        return 'BASE';
      case AppMode.proClient:
        return 'PRO CLIENT';
      case AppMode.proServer:
        return 'PRO SERVER';
    }
  }

  Color _getModeColor() {
    switch (BuildConfig.appMode) {
      case AppMode.base:
        return Colors.blue;
      case AppMode.proClient:
        return Colors.green;
      case AppMode.proServer:
        return Colors.purple;
    }
  }

  void _showProUpgrade(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TickEat PRO'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('La versione PRO include:'),
            SizedBox(height: 8),
            Text('• Sincronizzazione multi-dispositivo'),
            Text('• Gestione server centralizzato'),
            Text('• Report consolidati'),
            Text('• Backup automatico'),
            SizedBox(height: 12),
            Text('Per attivare la versione PRO, compila l\'app con le configurazioni appropriate.'),
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
    );
  }
}
