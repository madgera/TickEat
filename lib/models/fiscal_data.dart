/// Modelli per la gestione fiscale secondo le specifiche RT dell'Agenzia delle Entrate
import 'package:intl/intl.dart';

/// Aliquote IVA standard in Italia
enum VatRate {
  standard(22.0, 'Aliquota ordinaria'),
  reduced1(10.0, 'Aliquota ridotta'),
  reduced2(5.0, 'Aliquota ridotta'),
  reduced3(4.0, 'Aliquota ridotta'),
  exempt(0.0, 'Esente'),
  notSubject(0.0, 'Non soggetto');

  const VatRate(this.rate, this.description);
  final double rate;
  final String description;
}

/// Calcolo dettagliato IVA per un importo
class VatCalculation {
  final double netAmount;    // Importo netto (senza IVA)
  final double vatAmount;    // Importo IVA
  final double grossAmount;  // Importo lordo (con IVA)
  final VatRate vatRate;     // Aliquota applicata

  VatCalculation({
    required this.netAmount,
    required this.vatAmount,
    required this.grossAmount,
    required this.vatRate,
  });

  /// Calcola IVA da importo lordo
  factory VatCalculation.fromGross(double grossAmount, VatRate vatRate) {
    if (grossAmount < 0) {
      throw ArgumentError('L\'importo lordo non può essere negativo: $grossAmount');
    }
    
    final netAmount = grossAmount / (1 + vatRate.rate / 100);
    final vatAmount = grossAmount - netAmount;
    
    return VatCalculation(
      netAmount: double.parse(netAmount.toStringAsFixed(2)),
      vatAmount: double.parse(vatAmount.toStringAsFixed(2)),
      grossAmount: grossAmount,
      vatRate: vatRate,
    );
  }

  /// Calcola IVA da importo netto
  factory VatCalculation.fromNet(double netAmount, VatRate vatRate) {
    final vatAmount = netAmount * vatRate.rate / 100;
    final grossAmount = netAmount + vatAmount;
    
    return VatCalculation(
      netAmount: netAmount,
      vatAmount: double.parse(vatAmount.toStringAsFixed(2)),
      grossAmount: double.parse(grossAmount.toStringAsFixed(2)),
      vatRate: vatRate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'net_amount': netAmount,
      'vat_amount': vatAmount,
      'gross_amount': grossAmount,
      'vat_rate': vatRate.rate,
    };
  }
}

/// Riepilogo IVA per gruppi di aliquote
class VatSummary {
  final VatRate vatRate;
  final double totalNet;
  final double totalVat;
  final double totalGross;
  final int itemsCount;

  VatSummary({
    required this.vatRate,
    required this.totalNet,
    required this.totalVat,
    required this.totalGross,
    required this.itemsCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'vat_rate': vatRate.rate,
      'total_net': totalNet,
      'total_vat': totalVat,
      'total_gross': totalGross,
      'items_count': itemsCount,
    };
  }
}

/// Documento fiscale per corrispettivi elettronici
class FiscalDocument {
  final String documentId;           // ID univoco documento
  final String registryNumber;       // Numero di registro
  final DateTime issueDate;          // Data di emissione
  final FiscalDocumentType type;     // Tipo documento
  final List<FiscalItem> items;      // Righe del documento
  final VatSummary vatSummary;       // Riepilogo IVA
  final double totalAmount;          // Totale documento
  final PaymentMethod paymentMethod; // Metodo di pagamento
  final String? cashierName;         // Nome operatore
  final int? deviceId;              // ID cassa
  final String? lotteryCode;        // Codice lotteria scontrini
  final bool transmitted;           // Se trasmesso all'AdE
  final DateTime? transmissionDate; // Data trasmissione

  FiscalDocument({
    required this.documentId,
    required this.registryNumber,
    required this.issueDate,
    required this.type,
    required this.items,
    required this.vatSummary,
    required this.totalAmount,
    required this.paymentMethod,
    this.cashierName,
    this.deviceId,
    this.lotteryCode,
    this.transmitted = false,
    this.transmissionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'document_id': documentId,
      'registry_number': registryNumber,
      'issue_date': issueDate.toIso8601String(),
      'type': type.name,
      'vat_summary': vatSummary.toMap(),
      'total_amount': totalAmount,
      'payment_method': paymentMethod.name,
      'cashier_name': cashierName,
      'device_id': deviceId,
      'lottery_code': lotteryCode,
      'transmitted': transmitted ? 1 : 0,
      'transmission_date': transmissionDate?.toIso8601String(),
    };
  }

  /// Genera XML per trasmissione all'Agenzia delle Entrate
  String toXml() {
    final buffer = StringBuffer();
    
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<DatiFatturazioneElettronicaBody>');
    buffer.writeln('  <DatiGenerali>');
    buffer.writeln('    <DatiGeneraliDocumento>');
    buffer.writeln('      <TipoDocumento>${type.code}</TipoDocumento>');
    buffer.writeln('      <Divisa>EUR</Divisa>');
    buffer.writeln('      <Data>${DateFormat('yyyy-MM-dd').format(issueDate)}</Data>');
    buffer.writeln('      <Numero>$registryNumber</Numero>');
    buffer.writeln('    </DatiGeneraliDocumento>');
    buffer.writeln('  </DatiGenerali>');
    
    buffer.writeln('  <DatiBeniServizi>');
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln('    <DettaglioLinee>');
      buffer.writeln('      <NumeroLinea>${i + 1}</NumeroLinea>');
      buffer.writeln('      <Descrizione>${item.description}</Descrizione>');
      buffer.writeln('      <Quantita>${item.quantity.toStringAsFixed(2)}</Quantita>');
      buffer.writeln('      <PrezzoUnitario>${item.unitPrice.toStringAsFixed(2)}</PrezzoUnitario>');
      buffer.writeln('      <PrezzoTotale>${item.totalPrice.toStringAsFixed(2)}</PrezzoTotale>');
      buffer.writeln('      <AliquotaIVA>${item.vatCalculation.vatRate.rate.toStringAsFixed(2)}</AliquotaIVA>');
      buffer.writeln('    </DettaglioLinee>');
    }
    
    buffer.writeln('    <DatiRiepilogo>');
    buffer.writeln('      <AliquotaIVA>${vatSummary.vatRate.rate.toStringAsFixed(2)}</AliquotaIVA>');
    buffer.writeln('      <ImponibileImporto>${vatSummary.totalNet.toStringAsFixed(2)}</ImponibileImporto>');
    buffer.writeln('      <Imposta>${vatSummary.totalVat.toStringAsFixed(2)}</Imposta>');
    buffer.writeln('    </DatiRiepilogo>');
    buffer.writeln('  </DatiBeniServizi>');
    
    buffer.writeln('  <DatiPagamento>');
    buffer.writeln('    <CondizioniPagamento>TP02</CondizioniPagamento>');
    buffer.writeln('    <DettaglioPagamento>');
    buffer.writeln('      <ModalitaPagamento>${paymentMethod == PaymentMethod.cash ? 'MP01' : 'MP05'}</ModalitaPagamento>');
    buffer.writeln('      <ImportoPagamento>${totalAmount.toStringAsFixed(2)}</ImportoPagamento>');
    buffer.writeln('    </DettaglioPagamento>');
    buffer.writeln('  </DatiPagamento>');
    
    buffer.writeln('</DatiFatturazioneElettronicaBody>');
    
    return buffer.toString();
  }
}

/// Riga di un documento fiscale
class FiscalItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final VatCalculation vatCalculation;

  FiscalItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.vatCalculation,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'vat_calculation': vatCalculation.toMap(),
    };
  }
}

/// Tipi di documento fiscale
enum FiscalDocumentType {
  receipt('TD24', 'Corrispettivo telematico'),
  invoice('TD01', 'Fattura'),
  creditNote('TD04', 'Nota di credito');

  const FiscalDocumentType(this.code, this.description);
  final String code;
  final String description;
}

/// Metodi di pagamento (estendo l'enum esistente)
enum PaymentMethod { 
  cash, 
  electronic,
  creditCard,
  debitCard,
  check,
  bankTransfer
}

/// Giornale fiscale per registro movimenti
class FiscalJournal {
  final String journalId;
  final DateTime date;
  final List<FiscalDocument> documents;
  final Map<VatRate, VatSummary> vatSummaryByRate;
  final double totalDaily;
  final bool closed;
  final DateTime? closingDate;
  final String? signature; // Firma digitale per integrità

  FiscalJournal({
    required this.journalId,
    required this.date,
    required this.documents,
    required this.vatSummaryByRate,
    required this.totalDaily,
    this.closed = false,
    this.closingDate,
    this.signature,
  });

  Map<String, dynamic> toMap() {
    return {
      'journal_id': journalId,
      'date': date.toIso8601String(),
      'total_daily': totalDaily,
      'closed': closed ? 1 : 0,
      'closing_date': closingDate?.toIso8601String(),
      'signature': signature,
    };
  }

  /// Genera report giornaliero in formato XML per AdE
  String toXmlReport() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer();
    
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<RegistroCorrispettivi>');
    buffer.writeln('  <DataRegistro>${dateFormat.format(date)}</DataRegistro>');
    buffer.writeln('  <NumeroDocumenti>${documents.length}</NumeroDocumenti>');
    buffer.writeln('  <TotaleGiornaliero>${totalDaily.toStringAsFixed(2)}</TotaleGiornaliero>');
    
    buffer.writeln('  <RiepilogoIVA>');
    for (final entry in vatSummaryByRate.entries) {
      final summary = entry.value;
      buffer.writeln('    <AliquotaIVA>');
      buffer.writeln('      <Aliquota>${summary.vatRate.rate.toStringAsFixed(2)}</Aliquota>');
      buffer.writeln('      <Imponibile>${summary.totalNet.toStringAsFixed(2)}</Imponibile>');
      buffer.writeln('      <Imposta>${summary.totalVat.toStringAsFixed(2)}</Imposta>');
      buffer.writeln('    </AliquotaIVA>');
    }
    buffer.writeln('  </RiepilogoIVA>');
    
    buffer.writeln('  <Documenti>');
    for (final doc in documents) {
      buffer.writeln('    <Documento>');
      buffer.writeln('      <NumeroProgressivo>${doc.registryNumber}</NumeroProgressivo>');
      buffer.writeln('      <DataOra>${DateFormat('yyyy-MM-ddTHH:mm:ss').format(doc.issueDate)}</DataOra>');
      buffer.writeln('      <Importo>${doc.totalAmount.toStringAsFixed(2)}</Importo>');
      buffer.writeln('      <ModalitaPagamento>${doc.paymentMethod == PaymentMethod.cash ? 'CONTANTE' : 'ELETTRONICO'}</ModalitaPagamento>');
      if (doc.lotteryCode != null) {
        buffer.writeln('      <CodiceLotteria>${doc.lotteryCode}</CodiceLotteria>');
      }
      buffer.writeln('    </Documento>');
    }
    buffer.writeln('  </Documenti>');
    
    if (signature != null) {
      buffer.writeln('  <FirmaDigitale>$signature</FirmaDigitale>');
    }
    
    buffer.writeln('</RegistroCorrispettivi>');
    
    return buffer.toString();
  }
}

/// Configurazione fiscale per il registratore telematico
class FiscalConfiguration {
  final String vatNumber;           // Partita IVA
  final String taxCode;            // Codice fiscale
  final String businessName;       // Ragione sociale
  final String address;            // Indirizzo
  final String city;              // Città
  final String zipCode;           // CAP
  final String province;          // Provincia
  final String rtCertificate;     // Certificato RT
  final DateTime certificateExpiry; // Scadenza certificato
  final bool lotteryEnabled;      // Lotteria scontrini abilitata
  final VatRate defaultVatRate;   // Aliquota IVA predefinita

  FiscalConfiguration({
    required this.vatNumber,
    required this.taxCode,
    required this.businessName,
    required this.address,
    required this.city,
    required this.zipCode,
    required this.province,
    required this.rtCertificate,
    required this.certificateExpiry,
    this.lotteryEnabled = true,
    this.defaultVatRate = VatRate.standard,
  });

  Map<String, dynamic> toMap() {
    return {
      'vat_number': vatNumber,
      'tax_code': taxCode,
      'business_name': businessName,
      'address': address,
      'city': city,
      'zip_code': zipCode,
      'province': province,
      'rt_certificate': rtCertificate,
      'certificate_expiry': certificateExpiry.toIso8601String(),
      'lottery_enabled': lotteryEnabled ? 1 : 0,
      'default_vat_rate': defaultVatRate.rate,
    };
  }

  factory FiscalConfiguration.fromMap(Map<String, dynamic> map) {
    return FiscalConfiguration(
      vatNumber: map['vat_number'] ?? '',
      taxCode: map['tax_code'] ?? '',
      businessName: map['business_name'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      zipCode: map['zip_code'] ?? '',
      province: map['province'] ?? '',
      rtCertificate: map['rt_certificate'] ?? '',
      certificateExpiry: DateTime.parse(map['certificate_expiry']),
      lotteryEnabled: (map['lottery_enabled'] ?? 0) == 1,
      defaultVatRate: VatRate.values.firstWhere(
        (rate) => rate.rate == (map['default_vat_rate'] ?? 22.0),
        orElse: () => VatRate.standard,
      ),
    );
  }

  bool get isValid {
    return vatNumber.isNotEmpty &&
           taxCode.isNotEmpty &&
           businessName.isNotEmpty &&
           rtCertificate.isNotEmpty &&
           certificateExpiry.isAfter(DateTime.now());
  }
}
