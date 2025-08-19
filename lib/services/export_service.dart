import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import '../models/daily_report.dart';
import '../models/sale.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  ExportService._internal();
  factory ExportService() => _instance;

  // Esporta report giornaliero in CSV
  Future<String> exportDailyReportToCSV(DailyReport report) async {
    try {
      final buffer = StringBuffer();
      final dateFormat = DateFormat('dd/MM/yyyy');
      final timeFormat = DateFormat('HH:mm:ss');
      
      // Header del report
      buffer.writeln('TICKEAT - REPORT GIORNALIERO');
      buffer.writeln('Data,${dateFormat.format(report.date)}');
      buffer.writeln('Generato il,${dateFormat.format(DateTime.now())} ${timeFormat.format(DateTime.now())}');
      buffer.writeln('');
      
      // Riepilogo
      buffer.writeln('RIEPILOGO');
      buffer.writeln('Totale Vendite,€${report.totalRevenue.toStringAsFixed(2)}');
      buffer.writeln('Numero Transazioni,${report.totalTransactions}');
      buffer.writeln('Vendite Contanti,€${(report.totalsByPaymentMethod[PaymentMethod.cash] ?? 0).toStringAsFixed(2)}');
      buffer.writeln('Vendite Elettroniche,€${(report.totalsByPaymentMethod[PaymentMethod.electronic] ?? 0).toStringAsFixed(2)}');
      buffer.writeln('');
      
      // Vendite per prodotto
      buffer.writeln('VENDITE PER PRODOTTO');
      buffer.writeln('Prodotto,Quantità,Ricavo');
      for (final entry in report.categorySummaries.entries) {
        final summary = entry.value;
        buffer.writeln('${summary.categoryName},${summary.totalQuantity},€${summary.totalRevenue.toStringAsFixed(2)}');
      }
      buffer.writeln('');
      
      // Dettaglio transazioni
      buffer.writeln('DETTAGLIO TRANSAZIONI');
      buffer.writeln('Biglietto,Ora,Totale,Pagamento,Articoli');
      for (final sale in report.sales) {
        final itemsDesc = sale.items.map((item) => '${item.quantity}x ${item.productName}').join('; ');
        final paymentMethod = sale.paymentMethod == PaymentMethod.cash ? 'Contanti' : 'Elettronico';
        buffer.writeln('${sale.ticketId},${timeFormat.format(sale.createdAt)},€${sale.totalAmount.toStringAsFixed(2)},$paymentMethod,"$itemsDesc"');
      }
      
      return buffer.toString();
    } catch (e) {
      if (kDebugMode) {
        print('Errore durante l\'esportazione CSV: $e');
      }
      throw Exception('Errore durante l\'esportazione CSV: $e');
    }
  }

  // Esporta report giornaliero in PDF
  Future<String> exportDailyReportToPDF(DailyReport report) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('dd/MM/yyyy');
      final timeFormat = DateFormat('HH:mm:ss');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TICKEAT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Report Giornaliero', style: pw.TextStyle(fontSize: 16)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Data: ${dateFormat.format(report.date)}'),
                        pw.Text('Generato: ${dateFormat.format(DateTime.now())} ${timeFormat.format(DateTime.now())}'),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Riepilogo
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RIEPILOGO GIORNATA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Totale Vendite:'),
                        pw.Text('€${report.totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Numero Transazioni:'),
                        pw.Text('${report.totalTransactions}'),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Contanti:'),
                        pw.Text('€${(report.totalsByPaymentMethod[PaymentMethod.cash] ?? 0).toStringAsFixed(2)}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Elettronico:'),
                        pw.Text('€${(report.totalsByPaymentMethod[PaymentMethod.electronic] ?? 0).toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Vendite per prodotto
              if (report.categorySummaries.isNotEmpty) ...[
                pw.Text('VENDITE PER PRODOTTO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: ['Prodotto', 'Quantità', 'Ricavo'],
                  data: report.categorySummaries.entries.map((entry) {
                    final summary = entry.value;
                    return [
                      summary.categoryName,
                      summary.totalQuantity.toString(),
                      '€${summary.totalRevenue.toStringAsFixed(2)}',
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 20),
              ],
              
              // Dettaglio transazioni (prime 20)
              if (report.sales.isNotEmpty) ...[
                pw.Text('DETTAGLIO TRANSAZIONI', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: ['Biglietto', 'Ora', 'Totale', 'Pagamento'],
                  data: report.sales.take(20).map((sale) {
                    final paymentMethod = sale.paymentMethod == PaymentMethod.cash ? 'Contanti' : 'Elettronico';
                    return [
                      sale.ticketId,
                      timeFormat.format(sale.createdAt),
                      '€${sale.totalAmount.toStringAsFixed(2)}',
                      paymentMethod,
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                if (report.sales.length > 20)
                  pw.Text('\nMostrando prime 20 transazioni su ${report.sales.length} totali'),
              ],
            ];
          },
        ),
      );

      // Salva il file
      final fileName = 'tickeat_report_${DateFormat('yyyyMMdd').format(report.date)}.pdf';
      return await _savePdfFile(pdf, fileName);
    } catch (e) {
      if (kDebugMode) {
        print('Errore durante l\'esportazione PDF: $e');
      }
      throw Exception('Errore durante l\'esportazione PDF: $e');
    }
  }

  // Salva file CSV
  Future<String> saveCSVFile(String csvContent, String fileName) async {
    try {
      if (kIsWeb) {
        // Per il web, usiamo il download del browser
        await _downloadFileWeb(csvContent, fileName, 'text/csv');
        return 'Download iniziato';
      } else {
        // Per mobile/desktop, salva nel filesystem
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvContent, encoding: utf8);
        return file.path;
      }
    } catch (e) {
      throw Exception('Errore durante il salvataggio CSV: $e');
    }
  }

  // Salva file PDF
  Future<String> _savePdfFile(pw.Document pdf, String fileName) async {
    try {
      if (kIsWeb) {
        // Per il web, usiamo il download del browser
        final bytes = await pdf.save();
        await _downloadFileBytesWeb(bytes, fileName, 'application/pdf');
        return 'Download iniziato';
      } else {
        // Per mobile/desktop, salva nel filesystem
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        final bytes = await pdf.save();
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      throw Exception('Errore durante il salvataggio PDF: $e');
    }
  }

  // Download per web (simulato)
  Future<void> _downloadFileWeb(String content, String fileName, String mimeType) async {
    // In una vera implementazione web, useresti dart:html per scaricare il file
    if (kDebugMode) {
      print('Simulando download web: $fileName');
      print('Contenuto: ${content.substring(0, 100)}...');
    }
  }

  Future<void> _downloadFileBytesWeb(Uint8List bytes, String fileName, String mimeType) async {
    // In una vera implementazione web, useresti dart:html per scaricare il file
    if (kDebugMode) {
      print('Simulando download web: $fileName (${bytes.length} bytes)');
    }
  }

  // Apri file esportato
  Future<void> openExportedFile(String filePath) async {
    if (!kIsWeb && await File(filePath).exists()) {
      await OpenFile.open(filePath);
    }
  }

  // Esporta elenco vendite semplice
  Future<String> exportSalesListToCSV(List<Sale> sales, DateTime date) async {
    try {
      final buffer = StringBuffer();
      final dateFormat = DateFormat('dd/MM/yyyy');
      final timeFormat = DateFormat('HH:mm:ss');
      
      // Header
      buffer.writeln('TICKEAT - ELENCO VENDITE');
      buffer.writeln('Data,${dateFormat.format(date)}');
      buffer.writeln('');
      
      // Intestazioni
      buffer.writeln('Biglietto,Data,Ora,Totale,Pagamento,Dettagli');
      
      // Dati
      for (final sale in sales) {
        final paymentMethod = sale.paymentMethod == PaymentMethod.cash ? 'Contanti' : 'Elettronico';
        final details = sale.items.map((item) => '${item.quantity}x${item.productName}@€${item.unitPrice}').join('; ');
        buffer.writeln('${sale.ticketId},${dateFormat.format(sale.createdAt)},${timeFormat.format(sale.createdAt)},€${sale.totalAmount.toStringAsFixed(2)},$paymentMethod,"$details"');
      }
      
      return buffer.toString();
    } catch (e) {
      throw Exception('Errore durante l\'esportazione elenco vendite: $e');
    }
  }
}
