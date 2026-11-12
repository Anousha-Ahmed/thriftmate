import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

/// In-app notifications (collection: notifications).
///
/// Every write is best-effort: a failed notification must never break the
/// action that triggered it (sending an offer, placing an order...).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  Stream<List<AppNotification>> myNotifications(String uid) => _col
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final now = DateTime.now();
        final list = snap.docs.map(AppNotification.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
        return list;
      });

  Stream<int> unreadCount(String uid) =>
      myNotifications(uid).map((list) => list.where((n) => !n.read).length);

  Future<void> push({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
    String? orderId,
    String? chatId,
    String? itemId,
  }) async {
    if (userId.isEmpty) return;
    try {
      await _col.add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'orderId': ?orderId,
        'chatId': ?chatId,
        'itemId': ?itemId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notifications are a convenience, not part of the transaction.
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _col.doc(id).update({'read': true});
    } catch (_) {}
  }

  Future<void> markAllRead(Iterable<String> unreadIds) async {
    if (unreadIds.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final id in unreadIds) {
        batch.update(_col.doc(id), {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }
}
