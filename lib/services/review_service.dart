import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/review.dart';
import '../models/shop_order.dart';
import '../utils/format.dart';
import 'notification_service.dart';

class ReviewException implements Exception {
  const ReviewException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Buyer reviews of sellers (collection: reviews, doc id = order id, so a
/// buyer can rate each delivered order exactly once).
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _db.collection('reviews');

  Stream<List<Review>> sellerReviews(String sellerId) => _reviews
      .where('sellerId', isEqualTo: sellerId)
      .snapshots()
      .map((snap) {
        final now = DateTime.now();
        final list = snap.docs.map(Review.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
        return list;
      });

  Stream<Review?> watchOrderReview(String orderId) => _reviews
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? Review.fromDoc(doc) : null);

  Future<void> addReview({
    required ShopOrder order,
    required String buyerId,
    required String buyerName,
    required int rating,
    required String text,
  }) async {
    if (order.status != 'delivered') {
      throw const ReviewException(
        'You can rate the seller once the order is delivered.',
      );
    }
    if (order.buyerId != buyerId) {
      throw const ReviewException('Only the buyer can rate this order.');
    }
    if (rating < 1 || rating > 5) {
      throw const ReviewException('Choose a rating between 1 and 5 stars.');
    }

    final ref = _reviews.doc(order.id);
    final existing = await ref.get();
    if (existing.exists) {
      throw const ReviewException('You already rated this order.');
    }

    await ref.set({
      'orderId': order.id,
      'sellerId': order.sellerId,
      'buyerId': order.buyerId,
      'buyerName': buyerName,
      'rating': rating,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await NotificationService.instance.push(
      userId: order.sellerId,
      type: 'review',
      title: 'New review',
      body: '$buyerName rated you $rating★ · ${formatPrice(order.total)} order',
      orderId: order.id,
    );
  }
}
