import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import '../services/sales_service.dart';
import '../services/print_service.dart';
import '../models/product.dart';

import '../models/fiscal_data.dart';

import '../widgets/cart_widget.dart';
import '../widgets/payment_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  String _selectedCategory = 'Tutti';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    
    // Logica più granulare per i breakpoint
    final isPhone = screenWidth < 600;
    final isSmallTablet = screenWidth >= 600 && screenWidth < 900;
    final isTablet = screenWidth >= 900;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('TickEat - Punto Vendita'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          Consumer<SalesService>(
            builder: (context, salesService, child) {
              return FutureBuilder<Map<String, dynamic>>(
                future: salesService.getQuickStats(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final stats = snapshot.data!;
                    return Padding(
                      padding: EdgeInsets.all(isPhone ? 4.0 : 8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Oggi: €${stats['totalRevenue'].toStringAsFixed(2)}',
                            style: TextStyle(fontSize: isPhone ? 10 : 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${stats['totalTransactions']} vendite',
                            style: TextStyle(fontSize: isPhone ? 8 : 10),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ],
        bottom: (isPhone || isSmallTablet) ? TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.store), text: 'Prodotti'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Carrello'),
          ],
        ) : null,
      ),
      body: _buildResponsiveLayout(isPhone, isSmallTablet, isTablet),
    );
  }

  // Layout responsivo unificato
  Widget _buildResponsiveLayout(bool isPhone, bool isSmallTablet, bool isTablet) {
    if (isTablet) {
      // Layout tablet grande - split view
      return _buildTabletLayout();
    } else if (isSmallTablet) {
      // Layout tablet piccolo - split view verticale o orizzontale
      return _buildSmallTabletLayout();
    } else {
      // Layout phone - tab view senza bottomSheet
      return _buildPhoneLayout();
    }
  }

  // Layout per tablet grande (simile al precedente ma migliorato)
  Widget _buildTabletLayout() {
    return Row(
      children: [
        // Pannello prodotti
        Expanded(
          flex: 2,
          child: _buildProductsPanel(),
        ),
        // Pannello carrello
        SizedBox(
          width: 400,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey)),
            ),
            child: _buildCartPanel(),
          ),
        ),
      ],
    );
  }

  // Layout per tablet piccolo
  Widget _buildSmallTabletLayout() {
    return Row(
      children: [
        // Pannello prodotti - più ampio per evitare overflow
        Expanded(
          flex: 3,
          child: _buildProductsPanel(),
        ),
        // Pannello carrello - più stretto
        SizedBox(
          width: 300,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey)),
            ),
            child: _buildCartPanel(),
          ),
        ),
      ],
    );
  }

  // Layout per phone - SENZA bottomSheet problematico
  Widget _buildPhoneLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildProductsPanel(),
        _buildMobileOptimizedCartPanel(), // Versione ottimizzata per mobile
      ],
    );
  }

  // Pannello prodotti
  Widget _buildProductsPanel() {
    return Column(
      children: [
        // Barra di ricerca e filtri
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Cerca prodotti...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Consumer<ProductService>(
                builder: (context, productService, child) {
                  final categories = ['Tutti', ...productService.getCategories()];
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // Griglia prodotti
        Expanded(
          child: Consumer<ProductService>(
            builder: (context, productService, child) {
              List<Product> products;
              
              if (_searchQuery.isNotEmpty) {
                products = productService.searchProducts(_searchQuery);
              } else if (_selectedCategory == 'Tutti') {
                products = productService.activeProducts;
              } else {
                products = productService.getProductsByCategory(_selectedCategory);
              }

              return _buildResponsiveProductGrid(products);
            },
          ),
        ),
      ],
    );
  }

  // Griglia prodotti responsive - MIGLIORATA
  Widget _buildResponsiveProductGrid(List<Product> products) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    int crossAxisCount;
    double childAspectRatio;
    
    // Logica migliorata per i breakpoint
    if (screenWidth > 1200) {
      crossAxisCount = 5;
      childAspectRatio = 1.1;
    } else if (screenWidth > 900) {
      crossAxisCount = 4;
      childAspectRatio = 1.2;
    } else if (screenWidth > 600) {
      // Tablet piccolo - riduciamo le colonne per evitare overflow
      crossAxisCount = 2;
      childAspectRatio = 1.3;
    } else if (screenWidth > 400) {
      crossAxisCount = 2;
      childAspectRatio = 1.4;
    } else {
      // Phone molto piccolo
      crossAxisCount = 1;
      childAspectRatio = 2.0;
    }

    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nessun prodotto trovato', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(screenWidth > 600 ? 16 : 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: screenWidth > 600 ? 16 : 12,
        mainAxisSpacing: screenWidth > 600 ? 16 : 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildMobileProductCard(product);
      },
    );
  }

  // Card prodotto ottimizzata per mobile
  Widget _buildMobileProductCard(Product product) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        final quantity = cartService.getQuantity(product);
        
        return Card(
          elevation: 3,
          child: InkWell(
            onTap: () {
              cartService.addProduct(product);
              _showAddedToCartFeedback();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge categoria e quantità - layout flessibile
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 9 : 10,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (quantity > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Nome prodotto - responsive
                  Expanded(
                    child: Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      maxLines: isSmallScreen ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  
                  // Prezzo e controlli quantità - layout flessibile
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '€${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      if (quantity > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => cartService.decrementQuantity(product),
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: isSmallScreen ? 20 : 24,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 8),
                            IconButton(
                              onPressed: () => cartService.incrementQuantity(product),
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: isSmallScreen ? 20 : 24,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Pannello carrello
  Widget _buildCartPanel() {
    return Column(
      children: [
        // Header carrello
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Icon(Icons.shopping_cart),
              const SizedBox(width: 8),
              const Text(
                'Carrello',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Consumer<CartService>(
                builder: (context, cartService, child) {
                  return Text(
                    '${cartService.totalQuantity} articoli',
                    style: TextStyle(color: Colors.grey[600]),
                  );
                },
              ),
            ],
          ),
        ),
        const Expanded(child: CartWidget()),
        // Pulsanti azione
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey)),
          ),
          child: Consumer<CartService>(
            builder: (context, cartService, child) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: cartService.isEmpty ? null : () {
                            cartService.clear();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Svuota'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: cartService.isEmpty ? null : () => _showPaymentDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Incassa €${cartService.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // Pannello carrello ottimizzato per mobile - NUOVO
  Widget _buildMobileOptimizedCartPanel() {
    return Column(
      children: [
        // Header carrello con totale prominente
        Consumer<CartService>(
          builder: (context, cartService, child) {
            return Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Carrello',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${cartService.totalQuantity} articoli',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Totale prominente
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.euro, color: Colors.green, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          cartService.totalAmount.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        
        // Lista carrello
        const Expanded(child: CartWidget()),
        
        // Pulsanti azione - SEMPRE VISIBILI
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), // Padding extra in basso
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Consumer<CartService>(
              builder: (context, cartService, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Riga pulsanti principali
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: cartService.isEmpty ? null : () {
                              cartService.clear();
                            },
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Svuota'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: cartService.isEmpty ? null : () => _showPaymentDialog(context),
                            icon: const Icon(Icons.payment),
                            label: Text(
                              'Incassa €${cartService.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showAddedToCartFeedback() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prodotto aggiunto al carrello'),
        duration: Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PaymentDialog(
        totalAmount: context.read<CartService>().totalAmount,
        onPaymentCompleted: (paymentMethod, amountPaid, customerFiscalCode) async {
          await _processPayment(context, paymentMethod, amountPaid, customerFiscalCode);
        },
      ),
    );
  }

  Future<void> _processPayment(BuildContext context, PaymentMethod paymentMethod, double? amountPaid, String? customerFiscalCode) async {
    try {
      final cartService = context.read<CartService>();
      final salesService = context.read<SalesService>();
      final printService = PrintService();

      // Processa il pagamento
      final paymentResult = await salesService.processPayment(
        cartItems: cartService.items,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        cashierName: 'Operatore', // TODO: Implementare gestione utenti
        deviceId: 1, // TODO: Implementare gestione dispositivi
        customerFiscalCode: customerFiscalCode,
      );

      final ticketId = paymentResult['ticketId'] as String;
      final fiscalDocumentId = paymentResult['fiscalDocumentId'] as String?;
      final registryNumber = paymentResult['registryNumber'] as String?;
      final lotteryCode = paymentResult['lotteryCode'] as String?;

      // Ottieni la vendita per stampare il biglietto
      final todaySales = await salesService.getTodaySales();
      final sale = todaySales.firstWhere((s) => s.ticketId == ticketId);

      // Stampa il biglietto con le informazioni fiscali
      final printSuccess = await printService.printTicket(
        sale,
        lotteryCode: lotteryCode,
        fiscalDocumentId: fiscalDocumentId,
        registryNumber: registryNumber,
      );

      // Svuota il carrello
      cartService.clear();

      // Mostra messaggio di successo
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printSuccess 
                ? 'Vendita completata! Biglietto: $ticketId'
                : 'Vendita completata! (Errore stampa biglietto)',
            ),
            backgroundColor: printSuccess ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
