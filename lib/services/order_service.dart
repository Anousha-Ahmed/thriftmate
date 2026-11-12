import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../models/shop_order.dart';
import '../models/user_profile.dart';
import '../utils/format.dart';
import 'notification_service.dart';

class OrderException implements Exception {
  const OrderException(this.message);
  final String message;
}

/// Firestore access for orders (collection: orders).
class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ShopOrder>> buyerOrders(String buyerId) => _db
      .collection('orders')
      .where('buyerId', isEqualTo: buyerId)
      .snapshots()
      .map(_toSortedList);

  Stream<List<ShopOrder>> sellerOrders(String sellerId) => _db
      .collection('orders')
      .where('sellerId', isEqualTo: sellerId)
      .snapshots()
      .map(_toSortedList);

  Stream<ShopOrder?> watchOrder(String orderId) =>
      _db.collection('orders').doc(orderId).snapshots().map(
            (doc) => doc.exists ? ShopOrder.fromDoc(doc) : null,
          );

  List<ShopOrder> _toSortedList(QuerySnapshot<Map<String, dynamic>> snap) {
    final now = DateTime.now();
    final list = snap.docs.map(ShopOrder.fromDoc).toList();
    list.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    return list;
  }

  /// Places one order per seller and marks every purchased item as sold,
  /// all in a single transaction: either everything succeeds or nothing
  /// changes (so two buyers can never get the same item).
  ///
  /// [priceOverrides] lets an accepted offer change the price for that item.
  Future<List<String>> placeOrder({
    required UserProfile buyer,
    required List<Item> items,
    required ShippingAddress shipping,
    Map<String, int> priceOverrides = const {},
    String paymentMethod = 'cod',
    String paymentStatus = 'due',
    String? paymentIntentId,
  }) async {
    if (items.isEmpty) throw const OrderException('Your cart is empty.');

    final bySeller = <String, List<Item>>{};
    for (final item in items) {
      bySeller.putIfAbsent(item.sellerId, () => <Item>[]).add(item);
    }

    final orderIds = <String>[];
    final placed = <({String sellerId, String orderId, int total})>[];
    await _db.runTransaction((tx) async {
      orderIds.clear();
      placed.clear();

      // 1) Read and verify every item first.
      for (final item in items) {
        final snap = await tx.get(_db.collection('items').doc(item.id));
        final data = snap.data();
        if (data == null || data['status'] != 'active') {
          throw OrderException('"${item.name}" is no longer available.');
        }
        if (data['sellerId'] == buyer.uid) {
          throw const OrderException('You cannot buy your own item.');
        }
      }

      // 2) Then write: one order per seller + mark items sold.
      for (final entry in bySeller.entries) {
        final sellerItems = entry.value;
        final first = sellerItems.first;
        final subtotal = sellerItems.fold<int>(
            0, (s, i) => s + (priceOverrides[i.id] ?? i.price));
        final orderRef = _db.collection('orders').doc();

        tx.set(orderRef, {
          'buyerId': buyer.uid,
          'buyerName': buyer.name,
          'buyerUsername': buyer.username,
          'sellerId': entry.key,
          'sellerName': first.sellerName,
          'sellerUsername': first.sellerUsername,
          'lines': sellerItems
              .map((i) => OrderLine(
                    itemId: i.id,
                    name: i.name,
                    brand: i.brand,
                    size: i.size,
                    price: priceOverrides[i.id] ?? i.price,
                  ).toMap())
              .toList(),
          'subtotal': subtotal,
          'deliveryFee': kDeliveryFee,
          'status': 'pending',
          'shipping': shipping.toMap(),
          'paymentMethod': paymentMethod,
          'paymentStatus': paymentStatus,
          'paymentIntentId': ?paymentIntentId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        orderIds.add(orderRef.id);
        placed.add((
          sellerId: entry.key,
          orderId: orderRef.id,
          total: subtotal + kDeliveryFee,
        ));

        for (final i in sellerItems) {
          tx.update(_db.collection('items').doc(i.id), {'status': 'sold'});
        }
      }
    });

    for (final p in placed) {
      final shortId = p.orderId.length <= 6
          ? p.orderId.toUpperCase()
          : p.orderId.substring(0, 6).toUpperCase();
      await NotificationService.instance.push(
        userId: p.sellerId,
        type: 'order',
        title: 'New order received',
        body: 'Order #$shortId · ${formatPrice(p.total)}',
        orderId: p.orderId,
      );
    }
    return orderIds;
  }

  /// Seller moves an order forward: pending -> shipped -> delivered.
  Future<void> updateStatus(String orderId, String status) {
    return _db.collection('orders').doc(orderId).update({
      'status': status,
      if (status == 'shipped') 'shippedAt': FieldValue.serverTimestamp(),
      if (status == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
    });
  }
}
