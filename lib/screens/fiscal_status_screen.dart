/// Schermata per visualizzare lo stato fiscale e gestire i corrispettivi
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fiscal_data.dart';
import '../services/fiscal_service.dart';
import 'fiscal_config_screen.dart';

class FiscalStatusScreen extends StatefulWidget {
  const FiscalStatusScreen({super.key});

  @override
  State<FiscalStatusScreen> createState() => _FiscalStatusScreenState();
}

class _FiscalStatusScreenState extends State<FiscalStatusScreen> {
  final FiscalService _fiscalService = FiscalService();
  
  Map<String, dynamic> _complianceStatus = {};
  List<FiscalDocument> _todayDocuments = [];
  FiscalJournal? _todayJournal;
  bool _isLoading = false;
  bool _isTransmitting = false;
  bool _isClosingJournal = false;

  @override
  void initState() {
    super.initState();
    _loadFiscalStatus();
  }

  Future<void> _loadFiscalStatus() async {
    setState(() => _isLoading = true);
    
    try {
      await _fiscalService.initialize();
      _complianceStatus = _fiscalService.getComplianceStatus();
      
      final today = DateTime.now();
      _todayDocuments = await _fiscalService.getFiscalDocuments(startDate: today, endDate: today);
      _todayJournal = await _fiscalService.getFiscalJournalForDate(today);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore caricamento stato fiscale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _transmitTodayReceipts() async {
    setState(() => _isTransmitting = true);
    
    try {
      final today = DateTime.now();
      final success = await _fiscalService.transmitDailyReceipts(today);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Corrispettivi trasmessi con successo all\'AdE'),
            backgroundColor: Colors.green,
          ),
        );
        _loadFiscalStatus(); // Ricarica lo stato
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante la trasmissione dei corrispettivi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore trasmissione: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isTransmitting = false);
    }
  }

  Future<void> _closeDailyJournal() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chiusura Giornale Fiscale'),
        content: const Text(
          'Sei sicuro di voler chiudere il giornale fiscale per oggi?\n\n'
          'Questa operazione genererà il riepilogo definitivo della giornata e non potrà essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Chiudi Giornale'),
          ),
        ],
      ),
    );

    if (shouldClose != true) return;

    setState(() => _isClosingJournal = true);
    
    try {
      final today = DateTime.now();
      final journal = await _fiscalService.closeDailyJournal(today);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Giornale fiscale chiuso: ${journal.journalId}'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadFiscalStatus(); // Ricarica lo stato
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore chiusura giornale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isClosingJournal = false);
    }
  }

  Color _getStatusColor(bool isValid) {
    return isValid ? Colors.green : Colors.red;
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isValid,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: _getStatusColor(isValid),
          size: 32,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: isValid 
          ? Icon(Icons.check_circle, color: Colors.green[600])
          : Icon(Icons.error, color: Colors.red[600]),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDocumentsList() {
    if (_todayDocuments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Nessun documento fiscale emesso oggi',
            style: TextStyle(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Documenti di Oggi (${_todayDocuments.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todayDocuments.length,
            itemBuilder: (context, index) {
              final doc = _todayDocuments[index];
              return ListTile(
                leading: Icon(
                  doc.transmitted ? Icons.cloud_done : Icons.cloud_upload,
                  color: doc.transmitted ? Colors.green : Colors.orange,
                ),
                title: Text('Doc. ${doc.registryNumber}'),
                subtitle: Text(
                  '€${doc.totalAmount.toStringAsFixed(2)} - ${DateFormat('HH:mm').format(doc.issueDate)}'
                  '${doc.lotteryCode != null ? ' • Lotteria: ${doc.lotteryCode}' : ''}',
                ),
                trailing: doc.transmitted 
                  ? const Icon(Icons.check, color: Colors.green)
                  : const Icon(Icons.schedule, color: Colors.orange),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stato Fiscale'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiscalStatus,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const FiscalConfigScreen()),
              );
              _loadFiscalStatus();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFiscalStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stato di configurazione
                    _buildStatusCard(
                      title: 'Configurazione Fiscale',
                      subtitle: _complianceStatus['configured'] == true
                          ? 'Sistema configurato correttamente'
                          : 'Configurazione necessaria',
                      icon: Icons.settings,
                      isValid: _complianceStatus['configured'] == true,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const FiscalConfigScreen()),
                        );
                        _loadFiscalStatus();
                      },
                    ),

                    // Stato certificato
                    _buildStatusCard(
                      title: 'Certificato RT',
                      subtitle: _complianceStatus['certificate_valid'] == true
                          ? 'Certificato valido fino al ${_complianceStatus['certificate_expiry'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_complianceStatus['certificate_expiry'])) : 'N/A'}'
                          : 'Certificato scaduto o non configurato',
                      icon: Icons.card_membership,
                      isValid: _complianceStatus['certificate_valid'] == true,
                    ),

                    // Lotteria scontrini
                    _buildStatusCard(
                      title: 'Lotteria Scontrini',
                      subtitle: _complianceStatus['lottery_enabled'] == true
                          ? 'Abilitata'
                          : 'Disabilitata',
                      icon: Icons.confirmation_number,
                      isValid: true, // Non è obbligatoria
                    ),

                    const SizedBox(height: 24),

                    // Statistiche giornaliere
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.today, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Statistiche di Oggi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    'Documenti',
                                    '${_complianceStatus['daily_counter'] ?? 0}',
                                    Icons.receipt,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    'Totale',
                                    '€${_todayDocuments.fold(0.0, (sum, doc) => sum + doc.totalAmount).toStringAsFixed(2)}',
                                    Icons.euro,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    'Trasmessi',
                                    '${_todayDocuments.where((doc) => doc.transmitted).length}',
                                    Icons.cloud_done,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    'In Attesa',
                                    '${_todayDocuments.where((doc) => !doc.transmitted).length}',
                                    Icons.schedule,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Azioni
                    if (_complianceStatus['configured'] == true) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.send, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Azioni Fiscali',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _todayDocuments.isNotEmpty && !_isTransmitting
                                    ? _transmitTodayReceipts
                                    : null,
                                icon: _isTransmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(),
                                      )
                                    : const Icon(Icons.cloud_upload),
                                label: Text(_isTransmitting
                                    ? 'Trasmissione...'
                                    : 'Trasmetti Corrispettivi'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _todayDocuments.isNotEmpty && 
                                         _todayJournal?.closed != true && 
                                         !_isClosingJournal
                                    ? _closeDailyJournal
                                    : null,
                                icon: _isClosingJournal
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(),
                                      )
                                    : const Icon(Icons.lock),
                                label: Text(_isClosingJournal
                                    ? 'Chiusura...'
                                    : _todayJournal?.closed == true
                                        ? 'Giornale Chiuso'
                                        : 'Chiudi Giornale'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _todayJournal?.closed == true
                                      ? Colors.grey
                                      : Colors.orange[600],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],

                    // Lista documenti
                    _buildDocumentsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue[700], size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
