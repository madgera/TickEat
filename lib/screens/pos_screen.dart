import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import '../services/sales_service.dart';
import '../services/print_service.dart';
import '../models/product.dart';
import '../models/sale.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768; // Considera tablet se larghezza > 768px
    
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
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Oggi: €${stats['totalRevenue'].toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${stats['totalTransactions']} vendite',
                            style: const TextStyle(fontSize: 10),
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
        bottom: isTablet ? null : TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.store), text: 'Prodotti'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Carrello'),
          ],
        ),
      ),
      body: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      bottomSheet: isTablet ? null : _buildMobileCartSummary(),
    );
  }

  // Layout per tablet (simile al precedente ma migliorato)
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

  // Layout per mobile con TabBar
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProductsPanel(),
              _buildCartPanel(),
            ],
          ),
        ),
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

  // Griglia prodotti responsive
  Widget _buildResponsiveProductGrid(List<Product> products) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    
    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 768) {
      crossAxisCount = 3;
    } else if (screenWidth > 480) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
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
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: screenWidth > 768 ? 1.2 : 1.5,
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge categoria e quantità
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
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
                  
                  // Nome prodotto
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Prezzo e controlli quantità
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '€${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      if (quantity > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => cartService.decrementQuantity(product),
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 24,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => cartService.incrementQuantity(product),
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 24,
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

  // Riepilogo carrello mobile (bottom sheet)
  Widget? _buildMobileCartSummary() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 768) return null; // Solo per mobile
    
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        if (cartService.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cartService.totalQuantity} articoli',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        '€${cartService.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _tabController.animateTo(1); // Vai al tab carrello
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Visualizza Carrello'),
                ),
              ],
            ),
          ),
        );
      },
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
        onPaymentCompleted: (paymentMethod, amountPaid) async {
          await _processPayment(context, paymentMethod, amountPaid);
        },
      ),
    );
  }

  Future<void> _processPayment(BuildContext context, PaymentMethod paymentMethod, double? amountPaid) async {
    try {
      final cartService = context.read<CartService>();
      final salesService = context.read<SalesService>();
      final printService = PrintService();

      // Processa il pagamento
      final ticketId = await salesService.processPayment(
        cartItems: cartService.items,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        cashierName: 'Operatore', // TODO: Implementare gestione utenti
        deviceId: 1, // TODO: Implementare gestione dispositivi
      );

      // Ottieni la vendita per stampare il biglietto
      final todaySales = await salesService.getTodaySales();
      final sale = todaySales.firstWhere((s) => s.ticketId == ticketId);

      // Stampa il biglietto
      final printSuccess = await printService.printTicket(sale);

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
