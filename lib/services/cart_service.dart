import 'package:flutter/foundation.dart';

class CartItem {
  final Map<String, dynamic> product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  String get id       => product['_id'] as String? ?? '';
  String get name     => product['name'] as String? ?? '';
  String get brand    => product['brand'] as String? ?? '';
  num    get price    => (product['price'] as num?) ?? 0;
  String get unit     => product['unit'] as String? ?? '';
  String get category => product['category'] as String? ?? '';
  String get imageUrl => product['imageUrl'] as String? ?? '';
}

class CartService extends ChangeNotifier {
  static final CartService instance = CartService._();
  CartService._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, i) => sum + i.price * i.quantity);

  void add(Map<String, dynamic> product) {
    final idx = _items.indexWhere((i) => i.id == (product['_id'] ?? ''));
    if (idx >= 0) {
      _items[idx].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void increment(String productId) {
    final idx = _items.indexWhere((i) => i.id == productId);
    if (idx >= 0) {
      _items[idx].quantity++;
      notifyListeners();
    }
  }

  void decrement(String productId) {
    final idx = _items.indexWhere((i) => i.id == productId);
    if (idx >= 0) {
      if (_items[idx].quantity > 1) {
        _items[idx].quantity--;
      } else {
        _items.removeAt(idx);
      }
      notifyListeners();
    }
  }

  void remove(String productId) {
    _items.removeWhere((i) => i.id == productId);
    notifyListeners();
  }

  void setQuantity(String productId, int qty) {
    final idx = _items.indexWhere((i) => i.id == productId);
    if (idx < 0) return;
    if (qty <= 0) {
      _items.removeAt(idx);
    } else {
      _items[idx].quantity = qty;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void replaceAll(List<Map<String, dynamic>> items) {
    _items.clear();
    for (final m in items) {
      final qty = (m['_cart_qty'] as num?)?.toInt() ?? 1;
      final map = Map<String, dynamic>.from(m)..remove('_cart_qty');
      _items.add(CartItem(product: map, quantity: qty));
    }
    notifyListeners();
  }

  bool contains(String productId) => _items.any((i) => i.id == productId);
}
