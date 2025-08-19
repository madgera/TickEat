import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.length;

  int get totalQuantity => _items.fold(0, (total, item) => total + item.quantity);

  double get totalAmount => _items.fold(0.0, (total, item) => total + item.totalPrice);

  bool get isEmpty => _items.isEmpty;

  void addProduct(Product product) {
    final existingItemIndex = _items.indexWhere((item) => item.product.id == product.id);
    
    if (existingItemIndex >= 0) {
      _items[existingItemIndex].incrementQuantity();
    } else {
      _items.add(CartItem(product: product));
    }
    
    notifyListeners();
  }

  void removeProduct(Product product) {
    _items.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  void updateQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      removeProduct(product);
      return;
    }

    final existingItemIndex = _items.indexWhere((item) => item.product.id == product.id);
    
    if (existingItemIndex >= 0) {
      _items[existingItemIndex].setQuantity(quantity);
      notifyListeners();
    }
  }

  void incrementQuantity(Product product) {
    final existingItem = _items.firstWhere(
      (item) => item.product.id == product.id,
      orElse: () => CartItem(product: product, quantity: 0),
    );
    
    if (!_items.contains(existingItem)) {
      _items.add(existingItem);
    }
    
    existingItem.incrementQuantity();
    notifyListeners();
  }

  void decrementQuantity(Product product) {
    final existingItemIndex = _items.indexWhere((item) => item.product.id == product.id);
    
    if (existingItemIndex >= 0) {
      _items[existingItemIndex].decrementQuantity();
      
      if (_items[existingItemIndex].quantity == 0) {
        _items.removeAt(existingItemIndex);
      }
      
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  CartItem? getItem(Product product) {
    try {
      return _items.firstWhere((item) => item.product.id == product.id);
    } catch (e) {
      return null;
    }
  }

  int getQuantity(Product product) {
    final item = getItem(product);
    return item?.quantity ?? 0;
  }
}
