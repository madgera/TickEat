import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tickeat/models/fiscal_data.dart';
import '../services/sales_service.dart';
import '../services/export_service.dart';
import '../models/daily_report.dart';
import '../models/sale.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  DailyReport? _currentReport;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final salesService = context.read<SalesService>();
    final report = await salesService.generateDailyReport(_selectedDate);
    setState(() {
      _currentReport = report;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report e Statistiche'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'export_csv':
                  await _exportCSV();
                  break;
                case 'export_pdf':
                  await _exportPDF();
                  break;
                case 'reset':
                  _showResetDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Esporta CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Esporta PDF'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reset Dati', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selettore data
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                const Text('Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loadReport,
                  child: const Text('Aggiorna'),
                ),
              ],
            ),
          ),
          
          // Report content
          Expanded(
            child: _currentReport == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 24),
                        _buildPaymentMethodBreakdown(),
                        const SizedBox(height: 24),
                        _buildCategoryBreakdown(),
                        const SizedBox(height: 24),
                        _buildTransactionsList(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Vendite Totali',
            '€${_currentReport!.totalRevenue.toStringAsFixed(2)}',
            Icons.euro,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Transazioni',
            '${_currentReport!.totalTransactions}',
            Icons.receipt,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Suddivisione Pagamenti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.payments, size: 32, color: Colors.green),
                      const SizedBox(height: 8),
                      const Text('Contanti'),
                      Text(
                        '€${(_currentReport!.totalsByPaymentMethod[PaymentMethod.cash] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.credit_card, size: 32, color: Colors.blue),
                      const SizedBox(height: 8),
                      const Text('Elettronico'),
                      Text(
                        '€${(_currentReport!.totalsByPaymentMethod[PaymentMethod.electronic] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_currentReport!.categorySummaries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vendite per Prodotto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._currentReport!.categorySummaries.entries.map((entry) {
              final summary = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(summary.categoryName),
                    ),
                    Text('${summary.totalQuantity}x'),
                    const SizedBox(width: 16),
                    Text(
                      '€${summary.totalRevenue.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_currentReport!.sales.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nessuna transazione per questa data'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ultime Transazioni',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentReport!.sales.take(10).length,
              itemBuilder: (context, index) {
                final sale = _currentReport!.sales[index];
                return ListTile(
                  leading: Icon(
                    sale.paymentMethod == PaymentMethod.cash
                        ? Icons.payments
                        : Icons.credit_card,
                    color: sale.paymentMethod == PaymentMethod.cash
                        ? Colors.green
                        : Colors.blue,
                  ),
                  title: Text('Biglietto: ${sale.ticketId}'),
                  subtitle: Text(
                    DateFormat('HH:mm:ss').format(sale.createdAt),
                  ),
                  trailing: Text(
                    '€${sale.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _loadReport();
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Dati Giornalieri'),
        content: const Text(
          'Sei sicuro di voler cancellare tutti i dati delle vendite?\n\n'
          'Questa operazione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<SalesService>().resetDailyData();
              _loadReport();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dati reset completato')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCSV() async {
    if (_currentReport == null) return;

    try {
      _showLoadingDialog('Generando file CSV...');

      final exportService = ExportService();
      final csvContent = await exportService.exportDailyReportToCSV(_currentReport!);
      final fileName = 'tickeat_report_${DateFormat('yyyyMMdd').format(_selectedDate)}.csv';
      
      final filePath = await exportService.saveCSVFile(csvContent, fileName);

      if (mounted) {
        Navigator.pop(context); // Chiudi loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report esportato: $fileName'),
            action: SnackBarAction(
              label: 'Apri',
              onPressed: () => exportService.openExportedFile(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Chiudi loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore esportazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportPDF() async {
    if (_currentReport == null) return;

    try {
      _showLoadingDialog('Generando file PDF...');

      final exportService = ExportService();
      final filePath = await exportService.exportDailyReportToPDF(_currentReport!);

      if (mounted) {
        Navigator.pop(context); // Chiudi loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report PDF generato'),
            action: SnackBarAction(
              label: 'Apri',
              onPressed: () => exportService.openExportedFile(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Chiudi loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore generazione PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
