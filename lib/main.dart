import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'config/build_config.dart';
import 'services/product_service.dart';
import 'services/cart_service.dart';
import 'services/sales_service.dart';
import 'services/sync_service.dart';
import 'services/server_service.dart';
import 'screens/main_screen.dart';

void main() {
  // Debug info per modalità build
  if (kDebugMode) {
    print('=== TICKEAT BUILD INFO ===');
    BuildConfig.debugInfo.forEach((key, value) {
      print('$key: $value');
    });
    print('========================');
  }
  
  runApp(const TickEatApp());
}

class TickEatApp extends StatefulWidget {
  const TickEatApp({super.key});

  @override
  State<TickEatApp> createState() => _TickEatAppState();
}

class _TickEatAppState extends State<TickEatApp> {
  late ProductService _productService;
  late SalesService _salesService;
  SyncService? _syncService;      // Solo per PRO modes
  ServerService? _serverService;  // Solo per PRO SERVER mode

  @override
  void initState() {
    super.initState();
    _productService = ProductService();
    _salesService = SalesService();
    
    // Inizializzazione condizionale basata sulla modalità
    _initializeByMode();
  }

  void _initializeByMode() {
    if (kDebugMode) {
      print('Inizializzando modalità ${BuildConfig.appMode.name.toUpperCase()}...');
      print('Servizi richiesti: ${BuildConfig.requiredServices.join(', ')}');
    }
    
    // Inizializzazione condizionale per ottimizzare memoria e performance
    if (BuildConfig.shouldInitializeSyncService) {
      _syncService = SyncService();
      _productService.initializeSync();
      _salesService.initializeSync();
      _syncService!.initialize();
      
      if (kDebugMode) {
        print('✓ SyncService inizializzato');
      }
    }
    
    if (BuildConfig.shouldInitializeServerService) {
      _serverService = ServerService();
      _serverService!.loadServerConfig();
      
      // Collega il server service ai servizi locali per aggiornamenti
      _serverService!.setOnProductUpdatedCallback(() {
        _productService.loadProducts();
      });
      _serverService!.setOnSaleUpdatedCallback(() {
        _salesService.syncSalesFromServer();
      });
      
      if (kDebugMode) {
        print('✓ ServerService inizializzato');
      }
    }
    
    if (kDebugMode) {
      print('Inizializzazione completata. Memoria ottimizzata: ${BuildConfig.debugInfo['memoryOptimized']}');
    }
  }

  @override
  void dispose() {
    _productService.dispose();
    _salesService.dispose();
    _syncService?.dispose();
    _serverService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _productService),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider.value(value: _salesService),
        // Providers condizionali basati sulla modalità build
        if (_syncService != null)
          ChangeNotifierProvider.value(value: _syncService!),
        if (_serverService != null)
          ChangeNotifierProvider.value(value: _serverService!),
      ],
      child: MaterialApp(
        title: BuildConfig.appTitle,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            elevation: 2,
            centerTitle: true,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
