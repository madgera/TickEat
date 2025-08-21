import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/build_config.dart';
import '../services/product_service.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'device_management_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens {
    final screens = [
      const PosScreen(),
      const ProductsScreen(),
      const ReportsScreen(),
    ];
    
    // Aggiungi schede condizionali basate sulla configurazione build
    if (BuildConfig.shouldShowDeviceTab) {
      screens.add(const DeviceManagementScreen());
    }
    
    // Settings è sempre l'ultima scheda
    screens.add(const SettingsScreen());
    
    return screens;
  }

  List<BottomNavigationBarItem> get _navItems {
    final items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.point_of_sale),
        label: 'Cassa',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory),
        label: 'Prodotti',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.analytics),
        label: 'Report',
      ),
    ];
    
    // Aggiungi tab condizionali basate sulla configurazione build
    if (BuildConfig.shouldShowDeviceTab) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.devices),
        label: 'Dispositivi',
      ));
    }
    
    // Settings è sempre l'ultimo tab
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      label: 'Impostazioni',
    ));
    
    return items;
  }

  @override
  void initState() {
    super.initState();
    // Carica i prodotti all'avvio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductService>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey[600],
        items: _navItems,
      ),
    );
  }
}
