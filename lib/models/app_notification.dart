import 'package:cloud_firestore/cloud_firestore.dart';

/// One in-app notification: notifications/{id}.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.orderId,
    this.chatId,
    this.itemId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;

  /// 'order' | 'chat' | 'offer' | 'review' | 'system'
  final String type;
  final bool read;
  final String? orderId;
  final String? chatId;
  final String? itemId;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final ts = d['createdAt'];
    return AppNotification(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      title: (d['title'] ?? '') as String,
      body: (d['body'] ?? '') as String,
      type: (d['type'] ?? 'system') as String,
      read: (d['read'] ?? false) as bool,
      orderId: d['orderId'] as String?,
      chatId: d['chatId'] as String?,
      itemId: d['itemId'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
