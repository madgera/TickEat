import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/product_service.dart';
import '../models/product.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Prodotti'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showAddProductDialog(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Consumer<ProductService>(
        builder: (context, productService, child) {
          if (productService.products.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nessun prodotto trovato'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: productService.products.length,
            itemBuilder: (context, index) {
              final product = productService.products[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: product.isActive ? Colors.green : Colors.grey,
                    child: Icon(
                      product.isActive ? Icons.check : Icons.pause,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(product.name),
                  subtitle: Text('${product.category} - €${product.price.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => productService.toggleProductStatus(product),
                        icon: Icon(
                          product.isActive ? Icons.pause : Icons.play_arrow,
                          color: product.isActive ? Colors.orange : Colors.green,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showEditProductDialog(context, product),
                        icon: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    _showProductDialog(context, null);
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    _showProductDialog(context, product);
  }

  void _showProductDialog(BuildContext context, Product? product) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(text: product?.price.toStringAsFixed(2) ?? '');
    final categoryController = TextEditingController(text: product?.category ?? '');
    final descriptionController = TextEditingController(text: product?.description ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product == null ? 'Aggiungi Prodotto' : 'Modifica Prodotto',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome prodotto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Prezzo',
                  prefixText: '€ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final priceText = priceController.text.trim();
                        final category = categoryController.text.trim();
                        final description = descriptionController.text.trim();

                        if (name.isEmpty || priceText.isEmpty || category.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Compila tutti i campi obbligatori')),
                          );
                          return;
                        }

                        final price = double.tryParse(priceText);
                        if (price == null || price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Inserisci un prezzo valido')),
                          );
                          return;
                        }

                        if (product == null) {
                          // Aggiungi nuovo prodotto
                          final newProduct = Product(
                            name: name,
                            price: price,
                            category: category,
                            description: description.isEmpty ? null : description,
                          );
                          await context.read<ProductService>().addProduct(newProduct);
                        } else {
                          // Modifica prodotto esistente
                          final updatedProduct = product.copyWith(
                            name: name,
                            price: price,
                            category: category,
                            description: description.isEmpty ? null : description,
                          );
                          await context.read<ProductService>().updateProduct(updatedProduct);
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(product == null ? 'Prodotto aggiunto' : 'Prodotto modificato')),
                          );
                        }
                      },
                      child: Text(product == null ? 'Aggiungi' : 'Salva'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
