import 'package:flutter/foundation.dart';

class FavoriteItem {
  final String asset;       // image path — used as unique key
  final String name;
  final int    price;
  final String category;
  final String brand;
  final String description;
  const FavoriteItem({
    required this.asset,
    required this.name,
    required this.price,
    this.category    = '',
    this.brand       = '',
    this.description = '',
  });
}

/// Simple in-memory favorites store (singleton).
class FavoritesService extends ChangeNotifier {
  FavoritesService._();
  static final instance = FavoritesService._();

  final Map<String, FavoriteItem> _items = {};

  List<FavoriteItem> get items => List.unmodifiable(_items.values.toList());

  bool contains(String asset) => _items.containsKey(asset);

  void toggle(FavoriteItem item) {
    if (_items.containsKey(item.asset)) {
      _items.remove(item.asset);
    } else {
      _items[item.asset] = item;
    }
    notifyListeners();
  }

  void remove(String asset) {
    _items.remove(asset);
    notifyListeners();
  }
}
