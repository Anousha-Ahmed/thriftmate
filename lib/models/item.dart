import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared lists so Add Item, Home filters and Explore all stay in sync.
const List<String> kCategories = [
  'Tops',
  'Bottoms',
  'Dresses',
  'Outerwear',
  'Shoes',
  'Bags',
];
const List<String> kConditions = ['Like New', 'Good', 'Fair'];
const List<String> kSizes = [
  'XS', 'S', 'M', 'L', 'XL', 'XXL', 'One Size',
  '36', '37', '38', '39', '40', '41', '42', '43', '44', '45',
];

/// Business model: ThriftMate keeps this share of every sale.
const double kPlatformFeeRate = 0.10;

/// A clothing listing stored in Firestore: items/{itemId}.
class Item {
  Item({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerUsername,
    required this.name,
    required this.category,
    required this.brand,
    required this.size,
    required this.condition,
    required this.price,
    required this.description,
    required this.images,
    required this.status,
    required this.views,
    this.createdAt,
  });

  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerUsername;
  final String name;
  final String category;
  final String brand;
  final String size;
  final String condition;
  final int price; // PKR
  final String description;
  final List<String> images; // base64-encoded, compressed
  final String status; // 'active' or 'sold'
  final int views;
  final DateTime? createdAt;

  bool get isSold => status == 'sold';
  int get platformFee => (price * kPlatformFeeRate).round();
  int get sellerEarnings => price - platformFee;

  /// Decoded once per Item instance (not on every rebuild).
  late final Uint8List? coverBytes =
      images.isEmpty ? null : _safeDecode(images.first);

  static Uint8List? _safeDecode(String data) {
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  factory Item.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final ts = d['createdAt'];
    return Item(
      id: doc.id,
      sellerId: (d['sellerId'] ?? '') as String,
      sellerName: (d['sellerName'] ?? '') as String,
      sellerUsername: (d['sellerUsername'] ?? '') as String,
      name: (d['name'] ?? '') as String,
      category: (d['category'] ?? '') as String,
      brand: (d['brand'] ?? '') as String,
      size: (d['size'] ?? '') as String,
      condition: (d['condition'] ?? '') as String,
      price: ((d['price'] ?? 0) as num).toInt(),
      description: (d['description'] ?? '') as String,
      images: List<String>.from(d['images'] ?? const <String>[]),
      status: (d['status'] ?? 'active') as String,
      views: ((d['views'] ?? 0) as num).toInt(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
