import 'package:flutter/foundation.dart';
import '../models/item.dart';

/// The buyer's shopping cart. Kept in memory: thrift items are one-of-a-kind
/// (quantity is always 1), so the cart is short-lived by nature.
class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  final List<Item> _items = [];

  List<Item> get items => List.unmodifiable(_items);
  int get count => _items.length;
  int get subtotal => _items.fold<int>(0, (sum, i) => sum + i.price);

  bool contains(String itemId) => _items.any((i) => i.id == itemId);

  void add(Item item) {
    if (contains(item.id)) return;
    _items.add(item);
    notifyListeners();
  }

  void remove(String itemId) {
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
