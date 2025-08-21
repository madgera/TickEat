import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../config/build_config.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class ProductService extends ChangeNotifier {
  final StorageService _storageService = StorageServiceFactory.create();
  final SyncService _syncService = SyncService();
  List<Product> _products = [];
  List<Product> _activeProducts = [];

  List<Product> get products => List.unmodifiable(_products);
  List<Product> get activeProducts => List.unmodifiable(_activeProducts);

  Future<void> loadProducts() async {
    _products = await _storageService.getAllProducts();
    _activeProducts = await _storageService.getActiveProducts();
    
    // Se siamo connessi al server e la modalità lo supporta, sincronizza anche i prodotti dal server
    if (BuildConfig.shouldInitializeSyncService && _syncService.isConnected) {
      await _syncProductsFromServer();
    }
    
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    if (kDebugMode) {
      print('=== AGGIUNTA PRODOTTO ===');
      print('Prodotto da aggiungere: ${product.name}');
      print('Stato connessione sync: ${_syncService.isConnected}');
      print('Server URL: ${_syncService.serverUrl}');
    }
    
    // Salva localmente
    final productId = await _storageService.insertProduct(product);
    if (kDebugMode) {
      print('Prodotto salvato localmente con ID: $productId');
    }
    
    // Crea il prodotto con l'ID generato per la sincronizzazione
    final productWithId = product.copyWith(id: productId);
    
    // Sincronizza al server se connesso
    if (_syncService.isConnected) {
      if (kDebugMode) {
        print('Inizio sincronizzazione al server...');
        print('Dati prodotto da sincronizzare: ${productWithId.toMap()}');
      }
      
      // Sincronizza con il server se la modalità lo supporta
      if (BuildConfig.shouldInitializeSyncService) {
        try {
          await _syncService.syncProduct(productWithId);
          if (kDebugMode) {
            print('✅ Prodotto sincronizzato al server con successo: ${productWithId.name}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Errore sincronizzazione prodotto al server: $e');
          }
        }
      }
    } else {
      if (kDebugMode) {
        print('⚠️ Server non connesso - prodotto salvato solo localmente');
      }
    }
    
    await loadProducts();
    if (kDebugMode) {
      print('=== FINE AGGIUNTA PRODOTTO ===');
    }
  }

  Future<void> updateProduct(Product product) async {
    // Aggiorna localmente
    await _storageService.updateProduct(product);
    
    // Sincronizza al server se connesso
    if (_syncService.isConnected) {
      await _syncService.syncProduct(product);
      if (kDebugMode) {
        print('Aggiornamento prodotto sincronizzato al server: ${product.name}');
      }
    }
    
    await loadProducts();
  }

  Future<void> deleteProduct(int productId) async {
    await _storageService.deleteProduct(productId);
    await loadProducts();
  }

  Future<void> toggleProductStatus(Product product) async {
    final updatedProduct = product.copyWith(isActive: !product.isActive);
    await updateProduct(updatedProduct);
  }

  List<String> getCategories() {
    final categories = _products.map((product) => product.category).toSet().toList();
    categories.sort();
    return categories;
  }

  List<Product> getProductsByCategory(String category) {
    return _activeProducts.where((product) => product.category == category).toList();
  }

  Product? getProductById(int id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _activeProducts;
    
    final lowercaseQuery = query.toLowerCase();
    return _activeProducts.where((product) {
      return product.name.toLowerCase().contains(lowercaseQuery) ||
             product.category.toLowerCase().contains(lowercaseQuery) ||
             (product.description?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Sincronizza prodotti dal server
  Future<void> _syncProductsFromServer() async {
    try {
      if (kDebugMode) {
        print('Sincronizzando prodotti dal server...');
      }
      
      final serverProducts = await _syncService.getProductsFromServer();
      
      if (serverProducts.isNotEmpty) {
        for (final productData in serverProducts) {
          final product = Product.fromMap(productData);
          
          // Controlla se il prodotto esiste già localmente
          final existingProduct = _products.cast<Product?>().firstWhere(
            (p) => p?.id == product.id,
            orElse: () => null,
          );
          
          if (existingProduct == null) {
            // Prodotto nuovo dal server
            await _storageService.insertProduct(product);
            if (kDebugMode) {
              print('Nuovo prodotto ricevuto dal server: ${product.name}');
            }
          } else {
            // Aggiorna prodotto esistente (usa il timestamp più recente)
            await _storageService.updateProduct(product);
            if (kDebugMode) {
              print('Prodotto aggiornato dal server: ${product.name}');
            }
          }
        }
        
        // Ricarica la lista locale
        _products = await _storageService.getAllProducts();
        _activeProducts = await _storageService.getActiveProducts();
        
        if (kDebugMode) {
          print('Sincronizzazione prodotti completata: ${serverProducts.length} prodotti');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore sincronizzazione prodotti dal server: $e');
      }
    }
  }

  // Gestisce aggiornamenti di prodotti da altri dispositivi
  Future<void> handleRemoteProductUpdate(Map<String, dynamic> data) async {
    try {
      // Se è una richiesta di sync check, controlla aggiornamenti
      if (data['action'] == 'sync_check') {
        await _syncProductsFromServer();
        return;
      }
      
      // Altrimenti è un aggiornamento specifico di un prodotto
      final product = Product.fromMap(data);
      
      if (kDebugMode) {
        print('Ricevuto aggiornamento prodotto remoto: ${product.name}');
      }
      
      // Controlla se il prodotto esiste già localmente
      final existingProduct = _products.cast<Product?>().firstWhere(
        (p) => p?.id == product.id,
        orElse: () => null,
      );
      
      if (existingProduct == null) {
        // Nuovo prodotto
        await _storageService.insertProduct(product);
      } else {
        // Aggiorna prodotto esistente
        await _storageService.updateProduct(product);
      }
      
      // Ricarica e notifica l'interfaccia
      await loadProducts();
      
    } catch (e) {
      if (kDebugMode) {
        print('Errore gestendo aggiornamento prodotto remoto: $e');
      }
    }
  }

  // Inizializza il listener per aggiornamenti remoti
  void initializeSync() {
    // Ottimizzazione: inizializza sync solo se la modalità build lo richiede
    if (!BuildConfig.shouldInitializeSyncService) {
      if (kDebugMode) {
        print('ProductService: Sync non inizializzato (modalità ${BuildConfig.appMode.name})');
      }
      return;
    }
    
    if (kDebugMode) {
      print('ProductService: Inizializzando sync per modalità ${BuildConfig.appMode.name}');
    }
    
    _syncService.addListener(_onSyncServiceUpdate);
    _syncService.setOnRemoteProductUpdateCallback(handleRemoteProductUpdate);
  }

  void _onSyncServiceUpdate() {
    // Quando lo stato di connessione cambia, ricarica i prodotti
    if (_syncService.isConnected) {
      loadProducts();
    }
  }

  // Metodo di debug per forzare la sincronizzazione manuale
  Future<void> forceSyncToServer() async {
    if (!_syncService.isConnected) {
      if (kDebugMode) {
        print('⚠️ Impossibile sincronizzare: server non connesso');
      }
      return;
    }
    
    if (kDebugMode) {
      print('🔄 Forzando sincronizzazione di tutti i prodotti al server...');
    }
    
    for (final product in _products) {
      try {
        await _syncService.syncProduct(product);
        if (kDebugMode) {
          print('✅ Sincronizzato: ${product.name}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Errore sincronizzando ${product.name}: $e');
        }
      }
    }
    
    if (kDebugMode) {
      print('🔄 Sincronizzazione forzata completata');
    }
  }

  // Verifica stato sincronizzazione
  void checkSyncStatus() {
    if (kDebugMode) {
      print('=== STATO SINCRONIZZAZIONE PRODOTTI ===');
      print('Server connesso: ${_syncService.isConnected}');
      print('Server URL: ${_syncService.serverUrl}');
      print('Device ID: ${_syncService.deviceId}');
      print('Device Name: ${_syncService.deviceName}');
      print('Prodotti locali: ${_products.length}');
      print('=======================================');
    }
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncServiceUpdate);
    _syncService.removeOnRemoteProductUpdateCallback();
    super.dispose();
  }
}
