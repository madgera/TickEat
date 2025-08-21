enum AppMode { base, proClient, proServer }

class BuildConfig {
  static const String _modeKey = 'APP_MODE';
  
  // Cache per evitare calcoli ripetuti
  static AppMode? _cachedAppMode;
  
  // Configurazione di build (può essere sovrascritta da environment variables)
  static AppMode get appMode {
    return _cachedAppMode ??= _parseAppMode();
  }
  
  static AppMode _parseAppMode() {
    const modeStr = String.fromEnvironment(_modeKey, defaultValue: 'base');
    switch (modeStr.toLowerCase()) {
      case 'pro_client':
        return AppMode.proClient;
      case 'pro_server':
        return AppMode.proServer;
      case 'base':
      default:
        return AppMode.base;
    }
  }

  // Configurazioni per modalità
  static bool get isBaseMode => appMode == AppMode.base;
  static bool get isProClientMode => appMode == AppMode.proClient;
  static bool get isProServerMode => appMode == AppMode.proServer;
  static bool get isProMode => isProClientMode || isProServerMode;

  // Titoli app
  static String get appTitle {
    switch (appMode) {
      case AppMode.base:
        return 'TickEat - Registratore di Cassa (BASE)';
      case AppMode.proClient:
        return 'TickEat - Client PRO';
      case AppMode.proServer:
        return 'TickEat - Server PRO';
    }
  }

  // Features abilitate
  static bool get enableServerFeatures => isProServerMode;
  static bool get enableClientSync => isProClientMode;
  static bool get enableProConfig => isProMode;
  static bool get showProFeatures => isProMode;

  // URL e configurazioni di rete
  static String get defaultServerUrl => 'http://localhost:3000';
  static int get defaultServerPort => 3000;

  // Configurazioni UI
  static bool get showConnectionStatus => isProMode;
  static bool get showDeviceManagement => isProServerMode;
  static bool get showSyncStatus => isProClientMode;

  // Ottimizzazioni per performance
  static bool get shouldInitializeSyncService => isProMode;
  static bool get shouldInitializeServerService => isProServerMode;
  static bool get shouldShowDeviceTab => isProServerMode;
  static bool get shouldEnablePolling => isProMode;
  
  // Lista dei servizi da inizializzare
  static List<String> get requiredServices {
    final services = <String>['ProductService', 'SalesService', 'CartService'];
    if (shouldInitializeSyncService) services.add('SyncService');
    if (shouldInitializeServerService) services.add('ServerService');
    return services;
  }
  
  // Debug info
  static Map<String, dynamic> get debugInfo => {
    'appMode': appMode.toString(),
    'isBaseMode': isBaseMode,
    'isProClientMode': isProClientMode,
    'isProServerMode': isProServerMode,
    'appTitle': appTitle,
    'enableServerFeatures': enableServerFeatures,
    'enableClientSync': enableClientSync,
    'requiredServices': requiredServices,
    'memoryOptimized': !isProServerMode, // Server mode ha più servizi
  };
}
