import 'package:cloud_firestore/cloud_firestore.dart';

/// One buyer <-> seller negotiation about one listing.
/// Stored in Firestore: chats/{itemId}_{buyerId}
class ChatThread {
  const ChatThread({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemBrand,
    required this.itemSize,
    required this.itemPrice,
    required this.buyerId,
    required this.buyerName,
    required this.buyerUsername,
    required this.sellerId,
    required this.sellerName,
    required this.sellerUsername,
    required this.participants,
    required this.lastMessage,
    required this.lastSenderId,
    this.lastAt,
    this.createdAt,
    this.acceptedAmount,
  });

  final String id;
  final String itemId;
  final String itemName;
  final String itemBrand;
  final String itemSize;
  final int itemPrice;

  final String buyerId;
  final String buyerName;
  final String buyerUsername;
  final String sellerId;
  final String sellerName;
  final String sellerUsername;

  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastAt;
  final DateTime? createdAt;
  final int? acceptedAmount;

  bool get hasDeal => acceptedAmount != null;
  bool isBuyer(String uid) => uid == buyerId;
  bool isSeller(String uid) => uid == sellerId;

  String otherName(String uid) {
    final String name = uid == buyerId ? sellerName : buyerName;
    if (name.isNotEmpty) return name;
    return uid == buyerId ? sellerUsername : buyerUsername;
  }

  String otherUsername(String uid) =>
      uid == buyerId ? sellerUsername : buyerUsername;

  static DateTime? _date(dynamic value) =>
      value is Timestamp ? value.toDate() : null;

  factory ChatThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return ChatThread(
      id: doc.id,
      itemId: (d['itemId'] ?? '') as String,
      itemName: (d['itemName'] ?? '') as String,
      itemBrand: (d['itemBrand'] ?? '') as String,
      itemSize: (d['itemSize'] ?? '') as String,
      itemPrice: ((d['itemPrice'] ?? 0) as num).toInt(),
      buyerId: (d['buyerId'] ?? '') as String,
      buyerName: (d['buyerName'] ?? '') as String,
      buyerUsername: (d['buyerUsername'] ?? '') as String,
      sellerId: (d['sellerId'] ?? '') as String,
      sellerName: (d['sellerName'] ?? '') as String,
      sellerUsername: (d['sellerUsername'] ?? '') as String,
      participants: List<String>.from(d['participants'] ?? const <String>[]),
      lastMessage: (d['lastMessage'] ?? '') as String,
      lastSenderId: (d['lastSenderId'] ?? '') as String,
      lastAt: _date(d['lastAt']),
      createdAt: _date(d['createdAt']),
      acceptedAmount: d['acceptedAmount'] is num
          ? (d['acceptedAmount'] as num).toInt()
          : null,
    );
  }
}

/// A message inside a thread. Offers are messages with kind == 'offer'.
/// Stored in: chats/{chatId}/messages/{messageId}
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.kind,
    required this.text,
    required this.status,
    this.amount,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String kind; // 'text' | 'offer'
  final String text;
  final String status; // 'pending' | 'accepted' | 'declined'
  final int? amount;
  final DateTime? createdAt;

  bool get isOffer => kind == 'offer';
  bool get isPending => status == 'pending';

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final ts = d['createdAt'];
    return ChatMessage(
      id: doc.id,
      senderId: (d['senderId'] ?? '') as String,
      senderName: (d['senderName'] ?? '') as String,
      kind: (d['kind'] ?? 'text') as String,
      text: (d['text'] ?? '') as String,
      status: (d['status'] ?? 'pending') as String,
      amount: d['amount'] is num ? (d['amount'] as num).toInt() : null,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
