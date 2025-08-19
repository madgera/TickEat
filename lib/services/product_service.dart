import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'storage_service.dart';

class ProductService extends ChangeNotifier {
  final StorageService _storageService = StorageServiceFactory.create();
  List<Product> _products = [];
  List<Product> _activeProducts = [];

  List<Product> get products => List.unmodifiable(_products);
  List<Product> get activeProducts => List.unmodifiable(_activeProducts);

  Future<void> loadProducts() async {
    _products = await _storageService.getAllProducts();
    _activeProducts = await _storageService.getActiveProducts();
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    await _storageService.insertProduct(product);
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    await _storageService.updateProduct(product);
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
}
