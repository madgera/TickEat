import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/sale.dart';
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
      version: 1,
      onCreate: _createTables,
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
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Inserisci prodotti di esempio
    await _insertSampleProducts(db);
  }

  Future<void> _insertSampleProducts(Database db) async {
    final sampleProducts = [
      {
        'name': 'Panino con Porchetta',
        'price': 5.0,
        'category': 'Panini',
        'is_active': 1,
        'description': 'Panino con porchetta artigianale',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Birra Media',
        'price': 4.0,
        'category': 'Bevande',
        'is_active': 1,
        'description': 'Birra alla spina 0.4L',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Salsiccia alla Griglia',
        'price': 6.0,
        'category': 'Grill',
        'is_active': 1,
        'description': 'Salsiccia locale alla griglia',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Patatine Fritte',
        'price': 3.0,
        'category': 'Contorni',
        'is_active': 1,
        'description': 'Patatine fritte croccanti',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Acqua Naturale',
        'price': 1.5,
        'category': 'Bevande',
        'is_active': 1,
        'description': 'Bottiglia d\'acqua 0.5L',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Tiramisù',
        'price': 4.5,
        'category': 'Dolci',
        'is_active': 1,
        'description': 'Tiramisù fatto in casa',
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

  // Chiudi database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
