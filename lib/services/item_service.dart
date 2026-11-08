import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../models/user_profile.dart';

/// All Firestore access for listings (collection: items).
///
/// Queries use a single filter and sort on the device, so no composite
/// Firestore index is needed.
class ItemService {
  ItemService._();
  static final ItemService instance = ItemService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection('items');

  /// Every item that is still for sale (shown to buyers), newest first.
  Stream<List<Item>> activeItems() => _items
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map(_toSortedList);

  /// One seller's items (active and sold), newest first.
  Stream<List<Item>> sellerItems(String sellerId) => _items
      .where('sellerId', isEqualTo: sellerId)
      .snapshots()
      .map(_toSortedList);

  List<Item> _toSortedList(QuerySnapshot<Map<String, dynamic>> snap) {
    final now = DateTime.now();
    final list = snap.docs.map(Item.fromDoc).toList();
    list.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    return list;
  }

  Future<void> addItem({
    required UserProfile seller,
    required String name,
    required String category,
    required String brand,
    required String size,
    required String condition,
    required int price,
    required String description,
    required List<String> images,
  }) async {
    await _items.add({
      'sellerId': seller.uid,
      'sellerName': seller.name,
      'sellerUsername': seller.username,
      'name': name.trim(),
      'category': category,
      'brand': brand.trim(),
      'size': size,
      'condition': condition,
      'price': price,
      'description': description.trim(),
      'images': images,
      'status': 'active',
      'views': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(
    String id, {
    required String name,
    required String category,
    required String brand,
    required String size,
    required String condition,
    required int price,
    required String description,
    required List<String> images,
  }) async {
    await _items.doc(id).update({
      'name': name.trim(),
      'category': category,
      'brand': brand.trim(),
      'size': size,
      'condition': condition,
      'price': price,
      'description': description.trim(),
      'images': images,
    });
  }

  Future<void> markSold(String id) => _items.doc(id).update({'status': 'sold'});

  /// Counts a view when a buyer opens an item.
  Future<void> incrementViews(String id) =>
      _items.doc(id).update({'views': FieldValue.increment(1)});

  Future<void> deleteItem(String id) => _items.doc(id).delete();
}
