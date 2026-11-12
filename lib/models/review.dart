import 'package:cloud_firestore/cloud_firestore.dart';

/// A buyer's rating of a seller after a delivered order.
/// One review per order: reviews/{orderId}.
class Review {
  const Review({
    required this.id,
    required this.orderId,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    required this.rating,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String sellerId;
  final String buyerId;
  final String buyerName;
  final int rating; // 1..5
  final String text;
  final DateTime? createdAt;

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final ts = d['createdAt'];
    return Review(
      id: doc.id,
      orderId: (d['orderId'] ?? doc.id) as String,
      sellerId: (d['sellerId'] ?? '') as String,
      buyerId: (d['buyerId'] ?? '') as String,
      buyerName: (d['buyerName'] ?? '') as String,
      rating: ((d['rating'] ?? 0) as num).toInt().clamp(0, 5),
      text: (d['text'] ?? '') as String,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// Average of the valid ratings in [reviews]; 0 when there are none.
double averageRating(Iterable<Review> reviews) {
  var count = 0;
  var total = 0;
  for (final review in reviews) {
    if (review.rating <= 0) continue;
    count++;
    total += review.rating;
  }
  if (count == 0) return 0;
  return total / count;
}

/// "4.8" for 4.75, "5.0" for a perfect score.
String ratingLabel(double average) => average.toStringAsFixed(1);
