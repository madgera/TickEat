/// Servizio per la gestione della conformità fiscale secondo le specifiche RT dell'Agenzia delle Entrate
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';

import '../models/fiscal_data.dart';
import '../models/cart_item.dart';
import 'storage_service.dart';

class FiscalService extends ChangeNotifier {
  static final FiscalService _instance = FiscalService._internal();
  FiscalService._internal();
  factory FiscalService() => _instance;

  final StorageService _storageService = StorageServiceFactory.create();
  
  FiscalConfiguration? _configuration;
  int _dailyDocumentCounter = 0;
  String? _lastJournalId;

  /// Inizializza il servizio fiscale
  Future<void> initialize() async {
    await _loadConfiguration();
    await _initializeDailyCounter();
  }

  /// Carica la configurazione fiscale salvata
  Future<void> _loadConfiguration() async {
    try {
      final configData = await _storageService.getFiscalConfiguration();
      if (configData != null) {
        _configuration = FiscalConfiguration.fromMap(configData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore caricamento configurazione fiscale: $e');
      }
    }
  }

  /// Inizializza il contatore giornaliero dei documenti
  Future<void> _initializeDailyCounter() async {
    final today = DateTime.now();
    try {
      _dailyDocumentCounter = await _storageService.getDailyDocumentCount(today);
    } catch (e) {
      _dailyDocumentCounter = 0;
    }
  }

  /// Salva o aggiorna la configurazione fiscale
  Future<void> saveConfiguration(FiscalConfiguration config) async {
    await _storageService.saveFiscalConfiguration(config.toMap());
    _configuration = config;
    notifyListeners();
  }

  /// Verifica se il sistema è configurato correttamente per l'uso fiscale
  bool get isConfigured {
    return _configuration != null && _configuration!.isValid;
  }

  /// Ottiene la configurazione corrente
  FiscalConfiguration? get configuration => _configuration;

  /// Processa una vendita e genera il documento fiscale conforme
  Future<FiscalDocument> processFiscalSale({
    required List<CartItem> cartItems,
    required PaymentMethod paymentMethod,
    double? amountPaid,
    String? cashierName,
    int? deviceId,
    String? customerFiscalCode, // Per lotteria scontrini
  }) async {
    if (!isConfigured) {
      throw Exception('Sistema fiscale non configurato correttamente');
    }

    if (cartItems.isEmpty) {
      throw Exception('Il carrello è vuoto');
    }

    if (kDebugMode) {
      print('=== INIZIO PROCESSAMENTO FISCALE ===');
      print('Numero articoli nel carrello: ${cartItems.length}');
      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];
        print('Articolo $i: ${item.product.name} - Qty: ${item.quantity} - Prezzo: €${item.product.price} - IVA: ${item.product.vatRate.rate}% - Totale: €${item.totalPrice}');
      }
      print('=====================================');
    }

    // Incrementa il contatore giornaliero
    _dailyDocumentCounter++;
    
    // Genera ID documento e numero registro
    final documentId = _generateDocumentId();
    final registryNumber = _generateRegistryNumber();
    
    // Converti CartItem in FiscalItem con calcoli IVA
    final List<FiscalItem> fiscalItems = [];
    final Map<VatRate, List<VatCalculation>> vatByRate = {};
    
    for (final cartItem in cartItems) {
      final product = cartItem.product;
      final totalPrice = cartItem.totalPrice;
      
      // Verifica che il prodotto abbia dati validi
      if (totalPrice <= 0) {
        throw Exception('Prodotto ${product.name} ha prezzo non valido: €${totalPrice.toStringAsFixed(2)}');
      }
      
      // Calcola IVA per questo item
      final vatCalculation = VatCalculation.fromGross(totalPrice, product.vatRate);
      
      final fiscalItem = FiscalItem(
        description: product.name,
        quantity: cartItem.quantity,
        unitPrice: product.price,
        totalPrice: totalPrice,
        vatCalculation: vatCalculation,
      );
      
      fiscalItems.add(fiscalItem);
      
      // Raggruppa per aliquota IVA
      if (!vatByRate.containsKey(product.vatRate)) {
        vatByRate[product.vatRate] = [];
      }
      vatByRate[product.vatRate]!.add(vatCalculation);
    }

    // Calcola riepilogo IVA aggregando tutte le aliquote
    if (vatByRate.isEmpty) {
      throw Exception('Impossibile calcolare IVA: nessun prodotto valido nel carrello');
    }

    // Calcola totali aggregati da tutte le aliquote
    double totalNetAll = 0.0;
    double totalVatAll = 0.0;
    double totalGrossAll = 0.0;
    
    // Trova l'aliquota principale (quella con maggior importo)
    VatRate primaryVatRate = VatRate.standard;
    double maxGrossAmount = 0.0;
    
    for (final entry in vatByRate.entries) {
      final vatRate = entry.key;
      final calculations = entry.value;
      
      final netSum = calculations.fold(0.0, (sum, calc) => sum + calc.netAmount);
      final vatSum = calculations.fold(0.0, (sum, calc) => sum + calc.vatAmount);
      final grossSum = calculations.fold(0.0, (sum, calc) => sum + calc.grossAmount);
      
      totalNetAll += netSum;
      totalVatAll += vatSum;
      totalGrossAll += grossSum;
      
      // L'aliquota principale è quella con l'importo maggiore
      if (grossSum > maxGrossAmount) {
        maxGrossAmount = grossSum;
        primaryVatRate = vatRate;
      }
    }
    
    final vatSummary = VatSummary(
      vatRate: primaryVatRate,
      totalNet: totalNetAll,
      totalVat: totalVatAll,
      totalGross: totalGrossAll,
      itemsCount: fiscalItems.length,
    );

    final totalAmount = fiscalItems.fold(0.0, (sum, item) => sum + item.totalPrice);

    // Genera codice lotteria se richiesto e abilitato
    String? lotteryCode;
    if (_configuration!.lotteryEnabled && customerFiscalCode != null && customerFiscalCode.isNotEmpty) {
      lotteryCode = _generateLotteryCode();
    }

    // Crea documento fiscale
    final fiscalDocument = FiscalDocument(
      documentId: documentId,
      registryNumber: registryNumber,
      issueDate: DateTime.now(),
      type: FiscalDocumentType.receipt,
      items: fiscalItems,
      vatSummary: vatSummary,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      cashierName: cashierName,
      deviceId: deviceId,
      lotteryCode: lotteryCode,
      transmitted: false,
    );

    // Salva nel database
    await _storageService.saveFiscalDocument(fiscalDocument);
    
    // Aggiorna contatore giornaliero nel storage
    await _storageService.updateDailyDocumentCount(DateTime.now(), _dailyDocumentCounter);

    if (kDebugMode) {
      print('=== DOCUMENTO FISCALE GENERATO ===');
      print('ID: ${fiscalDocument.documentId}');
      print('Numero registro: ${fiscalDocument.registryNumber}');
      print('Articoli: ${fiscalDocument.items.length}');
      print('Aliquote IVA presenti: ${vatByRate.keys.map((rate) => '${rate.rate}%').join(', ')}');
      print('Aliquota principale: ${fiscalDocument.vatSummary.vatRate.rate}%');
      print('Imponibile: €${fiscalDocument.vatSummary.totalNet.toStringAsFixed(2)}');
      print('IVA: €${fiscalDocument.vatSummary.totalVat.toStringAsFixed(2)}');
      print('Totale: €${fiscalDocument.totalAmount.toStringAsFixed(2)}');
      if (lotteryCode != null) {
        print('Codice lotteria: $lotteryCode');
      }
      print('==================================');
    }

    return fiscalDocument;
  }

  /// Genera ID univoco per il documento
  String _generateDocumentId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final deviceId = _configuration?.rtCertificate.substring(0, 4) ?? 'UNKN';
    return 'DOC$deviceId${timestamp.toString().substring(8)}';
  }

  /// Genera numero progressivo di registro giornaliero
  String _generateRegistryNumber() {
    final today = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(today);
    final progressiveNumber = _dailyDocumentCounter.toString().padLeft(4, '0');
    return '$dateStr$progressiveNumber';
  }

  /// Genera codice per la lotteria degli scontrini
  String _generateLotteryCode() {
    final random = Random();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Chiude il giornale fiscale e genera il report giornaliero
  Future<FiscalJournal> closeDailyJournal(DateTime date) async {
    final documents = await _storageService.getFiscalDocumentsForDate(date);
    
    if (documents.isEmpty) {
      throw Exception('Nessun documento fiscale trovato per la data specificata');
    }

    // Calcola riepiloghi IVA per aliquota
    final Map<VatRate, List<VatCalculation>> vatByRate = {};
    double totalDaily = 0.0;

    for (final doc in documents) {
      totalDaily += doc.totalAmount;
      
      for (final item in doc.items) {
        final vatRate = item.vatCalculation.vatRate;
        if (!vatByRate.containsKey(vatRate)) {
          vatByRate[vatRate] = [];
        }
        vatByRate[vatRate]!.add(item.vatCalculation);
      }
    }

    // Crea riepiloghi IVA
    final Map<VatRate, VatSummary> vatSummaryByRate = {};
    for (final entry in vatByRate.entries) {
      final vatRate = entry.key;
      final calculations = entry.value;
      
      vatSummaryByRate[vatRate] = VatSummary(
        vatRate: vatRate,
        totalNet: calculations.fold(0.0, (sum, calc) => sum + calc.netAmount),
        totalVat: calculations.fold(0.0, (sum, calc) => sum + calc.vatAmount),
        totalGross: calculations.fold(0.0, (sum, calc) => sum + calc.grossAmount),
        itemsCount: calculations.length,
      );
    }

    // Genera ID giornale
    final journalId = 'JOURNAL_${DateFormat('yyyyMMdd').format(date)}';
    
    // Genera firma digitale per integrità
    final signature = _generateJournalSignature(documents, totalDaily);

    final journal = FiscalJournal(
      journalId: journalId,
      date: date,
      documents: documents,
      vatSummaryByRate: vatSummaryByRate,
      totalDaily: totalDaily,
      closed: true,
      closingDate: DateTime.now(),
      signature: signature,
    );

    // Salva il giornale
    await _storageService.saveFiscalJournal(journal);

    // Reset contatore per il giorno successivo
    if (DateFormat('yyyyMMdd').format(date) == DateFormat('yyyyMMdd').format(DateTime.now())) {
      _dailyDocumentCounter = 0;
    }

    _lastJournalId = journalId;
    notifyListeners();

    if (kDebugMode) {
      print('Giornale fiscale chiuso: $journalId');
      print('Documenti: ${documents.length}');
      print('Totale giornaliero: €${totalDaily.toStringAsFixed(2)}');
      print('Firma: ${signature.substring(0, 16)}...');
    }

    return journal;
  }

  /// Genera firma digitale per l'integrità del giornale
  String _generateJournalSignature(List<FiscalDocument> documents, double total) {
    final data = {
      'documents_count': documents.length,
      'total_amount': total,
      'document_ids': documents.map((d) => d.documentId).toList(),
      'timestamp': DateTime.now().toIso8601String(),
      'certificate': _configuration?.rtCertificate,
    };
    
    final jsonData = json.encode(data);
    final bytes = utf8.encode(jsonData);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Trasmette i corrispettivi giornalieri all'Agenzia delle Entrate
  Future<bool> transmitDailyReceipts(DateTime date) async {
    if (!isConfigured) {
      throw Exception('Sistema fiscale non configurato');
    }

    try {
      final journal = await _storageService.getFiscalJournalForDate(date);
      if (journal == null) {
        throw Exception('Giornale fiscale non trovato per la data specificata');
      }

      // Genera XML per trasmissione
      final xmlData = journal.toXmlReport();
      
      // Simula trasmissione (in produzione, qui ci sarebbe la chiamata SOAP all'AdE)
      await _simulateTransmission(xmlData);
      
      // Marca documenti come trasmessi
      for (final doc in journal.documents) {
        await _storageService.markDocumentAsTransmitted(doc.documentId, DateTime.now());
      }

      if (kDebugMode) {
        print('Corrispettivi trasmessi per ${DateFormat('dd/MM/yyyy').format(date)}');
        print('XML generato: ${xmlData.length} caratteri');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Errore trasmissione corrispettivi: $e');
      }
      return false;
    }
  }

  /// Simula la trasmissione all'Agenzia delle Entrate
  Future<void> _simulateTransmission(String xmlData) async {
    // Simula il tempo di trasmissione
    await Future.delayed(const Duration(seconds: 2));
    
    // In produzione, qui ci sarebbe:
    // 1. Validazione XML contro XSD dell'AdE
    // 2. Firma digitale del documento
    // 3. Chiamata SOAP al webservice dell'AdE
    // 4. Gestione della risposta e degli eventuali errori
    
    if (kDebugMode) {
      print('=== SIMULAZIONE TRASMISSIONE AdE ===');
      print('Dati XML validati e firmati digitalmente');
      print('Trasmissione completata con successo');
      print('====================================');
    }
  }

  /// Ottiene il report fiscale per una data specifica
  Future<FiscalJournal?> getFiscalJournalForDate(DateTime date) async {
    return await _storageService.getFiscalJournalForDate(date);
  }

  /// Ottiene tutti i documenti fiscali per un periodo
  Future<List<FiscalDocument>> getFiscalDocuments({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await _storageService.getFiscalDocumentsBetweenDates(startDate, endDate);
  }

  /// Verifica l'integrità del giornale fiscale
  Future<bool> verifyJournalIntegrity(String journalId) async {
    try {
      final journal = await _storageService.getFiscalJournalById(journalId);
      if (journal == null) return false;

      // Ricalcola la firma
      final recalculatedSignature = _generateJournalSignature(
        journal.documents, 
        journal.totalDaily
      );

      return recalculatedSignature == journal.signature;
    } catch (e) {
      if (kDebugMode) {
        print('Errore verifica integrità giornale: $e');
      }
      return false;
    }
  }

  /// Genera report per controlli fiscali
  Future<String> generateTaxAuditReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final documents = await getFiscalDocuments(startDate: startDate, endDate: endDate);
    
    final buffer = StringBuffer();
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    buffer.writeln('REPORT CONTROLLO FISCALE');
    buffer.writeln('========================');
    buffer.writeln('Periodo: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}');
    buffer.writeln('Generato il: ${dateFormat.format(DateTime.now())}');
    buffer.writeln('');
    
    if (_configuration != null) {
      buffer.writeln('DATI FISCALI ESERCENTE');
      buffer.writeln('Ragione Sociale: ${_configuration!.businessName}');
      buffer.writeln('Partita IVA: ${_configuration!.vatNumber}');
      buffer.writeln('Codice Fiscale: ${_configuration!.taxCode}');
      buffer.writeln('Indirizzo: ${_configuration!.address}, ${_configuration!.city} ${_configuration!.zipCode}');
      buffer.writeln('');
    }
    
    buffer.writeln('RIEPILOGO DOCUMENTI');
    buffer.writeln('Totale documenti: ${documents.length}');
    
    final totalAmount = documents.fold(0.0, (sum, doc) => sum + doc.totalAmount);
    buffer.writeln('Importo totale: €${totalAmount.toStringAsFixed(2)}');
    
    final totalVat = documents.fold(0.0, (sum, doc) => sum + doc.vatSummary.totalVat);
    buffer.writeln('IVA totale: €${totalVat.toStringAsFixed(2)}');
    
    final transmittedCount = documents.where((doc) => doc.transmitted).length;
    buffer.writeln('Documenti trasmessi: $transmittedCount/${documents.length}');
    buffer.writeln('');
    
    // Riepilogo per aliquota IVA
    final Map<double, double> totalsByVatRate = {};
    final Map<double, int> countsByVatRate = {};
    
    for (final doc in documents) {
      final vatRate = doc.vatSummary.vatRate.rate;
      totalsByVatRate[vatRate] = (totalsByVatRate[vatRate] ?? 0.0) + doc.totalAmount;
      countsByVatRate[vatRate] = (countsByVatRate[vatRate] ?? 0) + 1;
    }
    
    buffer.writeln('RIEPILOGO PER ALIQUOTA IVA');
    for (final entry in totalsByVatRate.entries) {
      final rate = entry.key;
      final total = entry.value;
      final count = countsByVatRate[rate]!;
      buffer.writeln('${rate.toStringAsFixed(1)}%: ${count} documenti, €${total.toStringAsFixed(2)}');
    }
    
    return buffer.toString();
  }

  /// Esporta dati per il commercialista in formato CSV
  Future<String> exportAccountingData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final documents = await getFiscalDocuments(startDate: startDate, endDate: endDate);
    
    final buffer = StringBuffer();
    
    // Header CSV
    buffer.writeln('Data;Ora;NumeroDocumento;ImportoNetto;ImportoIVA;ImportoTotale;AliquotaIVA;TipoPagamento;Trasmesso');
    
    // Dati
    for (final doc in documents) {
      final date = DateFormat('dd/MM/yyyy').format(doc.issueDate);
      final time = DateFormat('HH:mm:ss').format(doc.issueDate);
      final paymentType = doc.paymentMethod == PaymentMethod.cash ? 'CONTANTE' : 'ELETTRONICO';
      final transmitted = doc.transmitted ? 'SI' : 'NO';
      
      buffer.writeln(
        '$date;$time;${doc.registryNumber};${doc.vatSummary.totalNet.toStringAsFixed(2)};${doc.vatSummary.totalVat.toStringAsFixed(2)};${doc.totalAmount.toStringAsFixed(2)};${doc.vatSummary.vatRate.rate.toStringAsFixed(1)};$paymentType;$transmitted'
      );
    }
    
    return buffer.toString();
  }

  /// Verifica lo stato della conformità fiscale
  Map<String, dynamic> getComplianceStatus() {
    final status = <String, dynamic>{};
    
    status['configured'] = isConfigured;
    status['certificate_valid'] = _configuration?.certificateExpiry.isAfter(DateTime.now()) ?? false;
    status['lottery_enabled'] = _configuration?.lotteryEnabled ?? false;
    status['daily_counter'] = _dailyDocumentCounter;
    status['last_journal'] = _lastJournalId;
    
    if (_configuration != null) {
      status['vat_number'] = _configuration!.vatNumber;
      status['business_name'] = _configuration!.businessName;
      status['certificate_expiry'] = _configuration!.certificateExpiry.toIso8601String();
    }
    
    return status;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
