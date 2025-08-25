import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/fiscal_data.dart';
import 'database_config.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (!DatabaseConfig.isSupported) {
      throw UnsupportedError('Database non supportato su questa piattaforma');
    }
    
    await DatabaseConfig.initialize();
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'tickeat.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Tabella prodotti
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        description TEXT,
        vat_rate REAL DEFAULT 22.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabella vendite
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id TEXT UNIQUE NOT NULL,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        amount_paid REAL,
        change_given REAL,
        cashier_name TEXT,
        device_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabella dettagli vendita
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        total_price REAL NOT NULL,
        net_amount REAL DEFAULT 0.0,
        vat_amount REAL DEFAULT 0.0,
        vat_rate REAL DEFAULT 22.0,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Tabella configurazione fiscale
    await db.execute('''
      CREATE TABLE fiscal_configuration (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        vat_number TEXT NOT NULL,
        tax_code TEXT NOT NULL,
        business_name TEXT NOT NULL,
        address TEXT NOT NULL,
        city TEXT NOT NULL,
        zip_code TEXT NOT NULL,
        province TEXT NOT NULL,
        rt_certificate TEXT NOT NULL,
        certificate_expiry TEXT NOT NULL,
        lottery_enabled INTEGER DEFAULT 1,
        default_vat_rate REAL DEFAULT 22.0
      )
    ''');

    // Tabella documenti fiscali
    await db.execute('''
      CREATE TABLE fiscal_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id TEXT UNIQUE NOT NULL,
        registry_number TEXT NOT NULL,
        issue_date TEXT NOT NULL,
        type TEXT NOT NULL,
        total_amount REAL NOT NULL,
        net_amount REAL NOT NULL,
        vat_amount REAL NOT NULL,
        vat_rate REAL NOT NULL,
        payment_method TEXT NOT NULL,
        cashier_name TEXT,
        device_id INTEGER,
        lottery_code TEXT,
        transmitted INTEGER DEFAULT 0,
        transmission_date TEXT
      )
    ''');

    // Tabella righe documenti fiscali
    await db.execute('''
      CREATE TABLE fiscal_document_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id TEXT NOT NULL,
        description TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        net_amount REAL NOT NULL,
        vat_amount REAL NOT NULL,
        vat_rate REAL NOT NULL,
        FOREIGN KEY (document_id) REFERENCES fiscal_documents (document_id)
      )
    ''');

    // Tabella giornali fiscali
    await db.execute('''
      CREATE TABLE fiscal_journals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journal_id TEXT UNIQUE NOT NULL,
        date TEXT NOT NULL,
        total_daily REAL NOT NULL,
        closed INTEGER DEFAULT 0,
        closing_date TEXT,
        signature TEXT
      )
    ''');

    // Tabella contatori giornalieri
    await db.execute('''
      CREATE TABLE daily_counters (
        date TEXT PRIMARY KEY,
        document_count INTEGER DEFAULT 0
      )
    ''');

    // Inserisci prodotti di esempio
    await _insertSampleProducts(db);
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Aggiorna da versione 1 a 2 - aggiungi campi fiscali
      await db.execute('ALTER TABLE products ADD COLUMN vat_rate REAL DEFAULT 22.0');
      await db.execute('ALTER TABLE sale_items ADD COLUMN net_amount REAL DEFAULT 0.0');
      await db.execute('ALTER TABLE sale_items ADD COLUMN vat_amount REAL DEFAULT 0.0');
      await db.execute('ALTER TABLE sale_items ADD COLUMN vat_rate REAL DEFAULT 22.0');
      
      // Crea nuove tabelle fiscali
      await db.execute('''
        CREATE TABLE fiscal_configuration (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          vat_number TEXT NOT NULL,
          tax_code TEXT NOT NULL,
          business_name TEXT NOT NULL,
          address TEXT NOT NULL,
          city TEXT NOT NULL,
          zip_code TEXT NOT NULL,
          province TEXT NOT NULL,
          rt_certificate TEXT NOT NULL,
          certificate_expiry TEXT NOT NULL,
          lottery_enabled INTEGER DEFAULT 1,
          default_vat_rate REAL DEFAULT 22.0
        )
      ''');

      await db.execute('''
        CREATE TABLE fiscal_documents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id TEXT UNIQUE NOT NULL,
          registry_number TEXT NOT NULL,
          issue_date TEXT NOT NULL,
          type TEXT NOT NULL,
          total_amount REAL NOT NULL,
          net_amount REAL NOT NULL,
          vat_amount REAL NOT NULL,
          vat_rate REAL NOT NULL,
          payment_method TEXT NOT NULL,
          cashier_name TEXT,
          device_id INTEGER,
          lottery_code TEXT,
          transmitted INTEGER DEFAULT 0,
          transmission_date TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE fiscal_document_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id TEXT NOT NULL,
          description TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          total_price REAL NOT NULL,
          net_amount REAL NOT NULL,
          vat_amount REAL NOT NULL,
          vat_rate REAL NOT NULL,
          FOREIGN KEY (document_id) REFERENCES fiscal_documents (document_id)
        )
      ''');

      await db.execute('''
        CREATE TABLE fiscal_journals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          journal_id TEXT UNIQUE NOT NULL,
          date TEXT NOT NULL,
          total_daily REAL NOT NULL,
          closed INTEGER DEFAULT 0,
          closing_date TEXT,
          signature TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE daily_counters (
          date TEXT PRIMARY KEY,
          document_count INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<void> _insertSampleProducts(Database db) async {
    final sampleProducts = [
      {
        'name': 'Panino con Porchetta',
        'price': 5.0,
        'category': 'Panini',
        'is_active': 1,
        'description': 'Panino con porchetta artigianale',
        'vat_rate': 22.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Birra Media',
        'price': 4.0,
        'category': 'Bevande',
        'is_active': 1,
        'description': 'Birra alla spina 0.4L',
        'vat_rate': 22.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Salsiccia alla Griglia',
        'price': 6.0,
        'category': 'Grill',
        'is_active': 1,
        'description': 'Salsiccia locale alla griglia',
        'vat_rate': 10.0, // Aliquota ridotta per alimenti
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Patatine Fritte',
        'price': 3.0,
        'category': 'Contorni',
        'is_active': 1,
        'description': 'Patatine fritte croccanti',
        'vat_rate': 10.0, // Aliquota ridotta per alimenti
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Acqua Naturale',
        'price': 1.5,
        'category': 'Bevande',
        'is_active': 1,
        'description': 'Bottiglia d\'acqua 0.5L',
        'vat_rate': 10.0, // Aliquota ridotta per bevande
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Tiramisù',
        'price': 4.5,
        'category': 'Dolci',
        'is_active': 1,
        'description': 'Tiramisù fatto in casa',
        'vat_rate': 10.0, // Aliquota ridotta per dolci
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final product in sampleProducts) {
      await db.insert('products', product);
    }
  }

  // CRUD Prodotti
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Product>> getActiveProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'category, name',
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CRUD Vendite
  Future<int> insertSale(Sale sale) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      // Inserisci la vendita
      final saleId = await txn.insert('sales', sale.toMap());
      
      // Inserisci gli articoli della vendita
      for (final item in sale.items) {
        await txn.insert('sale_items', {
          ...item.toMap(),
          'sale_id': saleId,
        });
      }
      
      return saleId;
    });
  }

  Future<List<Sale>> getSalesForDate(DateTime date) async {
    final db = await database;
    
    // Ottieni le vendite per la data specificata
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    
    final salesMaps = await db.query(
      'sales',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'created_at DESC',
    );

    final sales = <Sale>[];
    for (final saleMap in salesMaps) {
      // Ottieni gli articoli per questa vendita
      final itemsMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleMap['id']],
      );
      
      final items = itemsMaps.map((itemMap) => SaleItem.fromMap(itemMap)).toList();
      sales.add(Sale.fromMap(saleMap, items));
    }

    return sales;
  }

  Future<List<Sale>> getAllSales() async {
    final db = await database;
    
    final salesMaps = await db.query(
      'sales',
      orderBy: 'created_at DESC',
    );

    final sales = <Sale>[];
    for (final saleMap in salesMaps) {
      final itemsMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleMap['id']],
      );
      
      final items = itemsMaps.map((itemMap) => SaleItem.fromMap(itemMap)).toList();
      sales.add(Sale.fromMap(saleMap, items));
    }

    return sales;
  }

  // Reset giornaliero
  Future<void> resetDailyData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('sales');
    });
  }

  // === METODI FISCALI ===

  // Configurazione fiscale
  Future<void> saveFiscalConfiguration(Map<String, dynamic> config) async {
    final db = await database;
    await db.insert(
      'fiscal_configuration',
      {...config, 'id': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getFiscalConfiguration() async {
    final db = await database;
    final result = await db.query('fiscal_configuration', where: 'id = ?', whereArgs: [1]);
    return result.isNotEmpty ? result.first : null;
  }

  // Documenti fiscali
  Future<int> saveFiscalDocument(FiscalDocument document) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      // Inserisci il documento
      final docId = await txn.insert('fiscal_documents', {
        'document_id': document.documentId,
        'registry_number': document.registryNumber,
        'issue_date': document.issueDate.toIso8601String(),
        'type': document.type.name,
        'total_amount': document.totalAmount,
        'net_amount': document.vatSummary.totalNet,
        'vat_amount': document.vatSummary.totalVat,
        'vat_rate': document.vatSummary.vatRate.rate,
        'payment_method': document.paymentMethod.name,
        'cashier_name': document.cashierName,
        'device_id': document.deviceId,
        'lottery_code': document.lotteryCode,
        'transmitted': document.transmitted ? 1 : 0,
        'transmission_date': document.transmissionDate?.toIso8601String(),
      });
      
      // Inserisci le righe del documento
      for (final item in document.items) {
        await txn.insert('fiscal_document_items', {
          'document_id': document.documentId,
          'description': item.description,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.totalPrice,
          'net_amount': item.vatCalculation.netAmount,
          'vat_amount': item.vatCalculation.vatAmount,
          'vat_rate': item.vatCalculation.vatRate.rate,
        });
      }
      
      return docId;
    });
  }

  Future<List<FiscalDocument>> getFiscalDocumentsForDate(DateTime date) async {
    final db = await database;
    
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    
    final docMaps = await db.query(
      'fiscal_documents',
      where: 'issue_date >= ? AND issue_date <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'issue_date ASC',
    );

    final documents = <FiscalDocument>[];
    for (final docMap in docMaps) {
      // Ottieni le righe per questo documento
      final itemsMaps = await db.query(
        'fiscal_document_items',
        where: 'document_id = ?',
        whereArgs: [docMap['document_id']],
      );
      
      final items = itemsMaps.map((itemMap) => FiscalItem(
        description: itemMap['description'] as String,
        quantity: itemMap['quantity'] as int,
        unitPrice: itemMap['unit_price'] as double,
        totalPrice: itemMap['total_price'] as double,
        vatCalculation: VatCalculation(
          netAmount: itemMap['net_amount'] as double,
          vatAmount: itemMap['vat_amount'] as double,
          grossAmount: itemMap['total_price'] as double,
          vatRate: VatRate.values.firstWhere(
            (rate) => rate.rate == (itemMap['vat_rate'] as double),
            orElse: () => VatRate.standard,
          ),
        ),
      )).toList();

      final vatRate = VatRate.values.firstWhere(
        (rate) => rate.rate == (docMap['vat_rate'] as double),
        orElse: () => VatRate.standard,
      );

      documents.add(FiscalDocument(
        documentId: docMap['document_id'] as String,
        registryNumber: docMap['registry_number'] as String,
        issueDate: DateTime.parse(docMap['issue_date'] as String),
        type: FiscalDocumentType.values.firstWhere(
          (type) => type.name == docMap['type'],
          orElse: () => FiscalDocumentType.receipt,
        ),
        items: items,
        vatSummary: VatSummary(
          vatRate: vatRate,
          totalNet: docMap['net_amount'] as double,
          totalVat: docMap['vat_amount'] as double,
          totalGross: docMap['total_amount'] as double,
          itemsCount: items.length,
        ),
        totalAmount: docMap['total_amount'] as double,
        paymentMethod: PaymentMethod.values.firstWhere(
          (method) => method.name == docMap['payment_method'],
          orElse: () => PaymentMethod.cash,
        ),
        cashierName: docMap['cashier_name'] as String?,
        deviceId: docMap['device_id'] as int?,
        lotteryCode: docMap['lottery_code'] as String?,
        transmitted: (docMap['transmitted'] as int) == 1,
        transmissionDate: docMap['transmission_date'] != null 
          ? DateTime.parse(docMap['transmission_date'] as String)
          : null,
      ));
    }

    return documents;
  }

  Future<List<FiscalDocument>> getFiscalDocumentsBetweenDates(DateTime startDate, DateTime endDate) async {
    final db = await database;
    
    final docMaps = await db.query(
      'fiscal_documents',
      where: 'issue_date >= ? AND issue_date <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'issue_date ASC',
    );

    final documents = <FiscalDocument>[];
    for (final docMap in docMaps) {
      final itemsMaps = await db.query(
        'fiscal_document_items',
        where: 'document_id = ?',
        whereArgs: [docMap['document_id']],
      );
      
      final items = itemsMaps.map((itemMap) => FiscalItem(
        description: itemMap['description'] as String,
        quantity: itemMap['quantity'] as int,
        unitPrice: itemMap['unit_price'] as double,
        totalPrice: itemMap['total_price'] as double,
        vatCalculation: VatCalculation(
          netAmount: itemMap['net_amount'] as double,
          vatAmount: itemMap['vat_amount'] as double,
          grossAmount: itemMap['total_price'] as double,
          vatRate: VatRate.values.firstWhere(
            (rate) => rate.rate == (itemMap['vat_rate'] as double),
            orElse: () => VatRate.standard,
          ),
        ),
      )).toList();

      final vatRate = VatRate.values.firstWhere(
        (rate) => rate.rate == (docMap['vat_rate'] as double),
        orElse: () => VatRate.standard,
      );

      documents.add(FiscalDocument(
        documentId: docMap['document_id'] as String,
        registryNumber: docMap['registry_number'] as String,
        issueDate: DateTime.parse(docMap['issue_date'] as String),
        type: FiscalDocumentType.values.firstWhere(
          (type) => type.name == docMap['type'],
          orElse: () => FiscalDocumentType.receipt,
        ),
        items: items,
        vatSummary: VatSummary(
          vatRate: vatRate,
          totalNet: docMap['net_amount'] as double,
          totalVat: docMap['vat_amount'] as double,
          totalGross: docMap['total_amount'] as double,
          itemsCount: items.length,
        ),
        totalAmount: docMap['total_amount'] as double,
        paymentMethod: PaymentMethod.values.firstWhere(
          (method) => method.name == docMap['payment_method'],
          orElse: () => PaymentMethod.cash,
        ),
        cashierName: docMap['cashier_name'] as String?,
        deviceId: docMap['device_id'] as int?,
        lotteryCode: docMap['lottery_code'] as String?,
        transmitted: (docMap['transmitted'] as int) == 1,
        transmissionDate: docMap['transmission_date'] != null 
          ? DateTime.parse(docMap['transmission_date'] as String)
          : null,
      ));
    }

    return documents;
  }

  Future<void> markDocumentAsTransmitted(String documentId, DateTime transmissionDate) async {
    final db = await database;
    await db.update(
      'fiscal_documents',
      {
        'transmitted': 1,
        'transmission_date': transmissionDate.toIso8601String(),
      },
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  // Giornali fiscali
  Future<int> saveFiscalJournal(FiscalJournal journal) async {
    final db = await database;
    return await db.insert('fiscal_journals', journal.toMap());
  }

  Future<FiscalJournal?> getFiscalJournalForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    
    final result = await db.query(
      'fiscal_journals',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
    );
    
    if (result.isEmpty) return null;
    
    final journalMap = result.first;
    final documents = await getFiscalDocumentsForDate(date);
    
    return FiscalJournal(
      journalId: journalMap['journal_id'] as String,
      date: DateTime.parse(journalMap['date'] as String),
      documents: documents,
      vatSummaryByRate: {}, // Ricostruito dai documenti
      totalDaily: journalMap['total_daily'] as double,
      closed: (journalMap['closed'] as int) == 1,
      closingDate: journalMap['closing_date'] != null 
        ? DateTime.parse(journalMap['closing_date'] as String)
        : null,
      signature: journalMap['signature'] as String?,
    );
  }

  Future<FiscalJournal?> getFiscalJournalById(String journalId) async {
    final db = await database;
    final result = await db.query(
      'fiscal_journals',
      where: 'journal_id = ?',
      whereArgs: [journalId],
    );
    
    if (result.isEmpty) return null;
    
    final journalMap = result.first;
    final date = DateTime.parse(journalMap['date'] as String);
    final documents = await getFiscalDocumentsForDate(date);
    
    return FiscalJournal(
      journalId: journalMap['journal_id'] as String,
      date: date,
      documents: documents,
      vatSummaryByRate: {}, // Ricostruito dai documenti
      totalDaily: journalMap['total_daily'] as double,
      closed: (journalMap['closed'] as int) == 1,
      closingDate: journalMap['closing_date'] != null 
        ? DateTime.parse(journalMap['closing_date'] as String)
        : null,
      signature: journalMap['signature'] as String?,
    );
  }

  // Contatori giornalieri
  Future<int> getDailyDocumentCount(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    
    final result = await db.query(
      'daily_counters',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    
    return result.isNotEmpty ? result.first['document_count'] as int : 0;
  }

  Future<void> updateDailyDocumentCount(DateTime date, int count) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    
    await db.insert(
      'daily_counters',
      {'date': dateStr, 'document_count': count},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Chiudi database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
