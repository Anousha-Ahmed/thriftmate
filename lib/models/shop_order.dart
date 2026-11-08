import 'package:cloud_firestore/cloud_firestore.dart';
import 'item.dart';

/// Flat delivery charge, applied once per seller in an order.
const int kDeliveryFee = 200;

int deliveryFeeFor(Iterable<Item> items) =>
    items.map((i) => i.sellerId).toSet().length * kDeliveryFee;

/// One item inside an order (a snapshot, so the order stays correct even
/// if the listing is edited later).
class OrderLine {
  const OrderLine({
    required this.itemId,
    required this.name,
    required this.brand,
    required this.size,
    required this.price,
  });

  final String itemId;
  final String name;
  final String brand;
  final String size;
  final int price;

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'name': name,
        'brand': brand,
        'size': size,
        'price': price,
      };

  factory OrderLine.fromMap(Map<String, dynamic> m) => OrderLine(
        itemId: (m['itemId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        brand: (m['brand'] ?? '') as String,
        size: (m['size'] ?? '') as String,
        price: ((m['price'] ?? 0) as num).toInt(),
      );
}

class ShippingAddress {
  const ShippingAddress({
    required this.name,
    required this.phone,
    required this.city,
    required this.address,
  });

  final String name;
  final String phone;
  final String city;
  final String address;

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'city': city,
        'address': address,
      };

  factory ShippingAddress.fromMap(Map<String, dynamic> m) => ShippingAddress(
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        city: (m['city'] ?? '') as String,
        address: (m['address'] ?? '') as String,
      );
}

/// An order from one buyer to one seller: orders/{orderId}.
class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.sellerUsername,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.status,
    required this.shipping,
    this.createdAt,
    this.shippedAt,
    this.deliveredAt,
  });

  final String id;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final String sellerUsername;
  final List<OrderLine> lines;
  final int subtotal;
  final int deliveryFee;
  final String status; // pending, shipped, delivered
  final ShippingAddress shipping;
  final DateTime? createdAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  int get total => subtotal + deliveryFee;
  int get platformFee => (subtotal * kPlatformFeeRate).round();
  int get sellerEarnings => subtotal - platformFee;
  String get shortId => id.length <= 6 ? id.toUpperCase() : id.substring(0, 6).toUpperCase();

  String get itemsSummary {
    if (lines.isEmpty) return '';
    final first = lines.first.name;
    return lines.length == 1 ? first : '$first +${lines.length - 1} more';
  }

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory ShopOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final rawLines = (d['lines'] as List?) ?? const [];
    return ShopOrder(
      id: doc.id,
      buyerId: (d['buyerId'] ?? '') as String,
      buyerName: (d['buyerName'] ?? '') as String,
      sellerId: (d['sellerId'] ?? '') as String,
      sellerName: (d['sellerName'] ?? '') as String,
      sellerUsername: (d['sellerUsername'] ?? '') as String,
      lines: rawLines
          .map((e) => OrderLine.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: ((d['subtotal'] ?? 0) as num).toInt(),
      deliveryFee: ((d['deliveryFee'] ?? 0) as num).toInt(),
      status: (d['status'] ?? 'pending') as String,
      shipping: ShippingAddress.fromMap(
          Map<String, dynamic>.from((d['shipping'] ?? const {}) as Map)),
      createdAt: _date(d['createdAt']),
      shippedAt: _date(d['shippedAt']),
      deliveredAt: _date(d['deliveredAt']),
    );
  }
}
