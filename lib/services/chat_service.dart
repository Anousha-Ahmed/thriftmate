import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';
import '../models/item.dart';
import '../models/user_profile.dart';
import '../utils/format.dart';

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Offer negotiation + chat, backed by Firestore.
///
///   chats/{itemId}_{buyerId}
///     participants: [buyerId, sellerId]
///     lastMessage / lastAt / lastSenderId  -> chat list preview
///     acceptedAmount                        -> agreed price, if any
///   chats/{itemId}_{buyerId}/messages/{messageId}
///     kind: 'text' | 'offer', amount, status: pending|accepted|declined
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  /// Every thread the signed-in user takes part in, newest activity first.
  Stream<List<ChatThread>> myThreads(String uid) => _chats
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((snap) {
        final now = DateTime.now();
        final list = snap.docs.map(ChatThread.fromDoc).toList();
        list.sort((a, b) => (b.lastAt ?? now).compareTo(a.lastAt ?? now));
        return list;
      });

  Stream<ChatThread?> watchThread(String chatId) => _chats
      .doc(chatId)
      .snapshots()
      .map((doc) => doc.exists ? ChatThread.fromDoc(doc) : null);

  Future<ChatThread?> getThread(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    return doc.exists ? ChatThread.fromDoc(doc) : null;
  }

  Stream<List<ChatMessage>> messages(String chatId) => _messages(chatId)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());

  /// Opens (or reuses) the buyer's chat for this item without sending an
  /// offer, so buyers can simply ask the seller a question first.
  Future<String> startChat({
    required Item item,
    required UserProfile buyer,
  }) async {
    if (item.sellerId == buyer.uid) {
      throw const ChatException('You cannot chat about your own item.');
    }
    final chatId = '${item.id}_${buyer.uid}';
    await _ensureThread(chatId: chatId, item: item, buyer: buyer);
    return chatId;
  }

  /// Starts (or reuses) the buyer's thread for this item and sends an offer.
  Future<String> openThread({
    required Item item,
    required UserProfile buyer,
    required int amount,
    required String note,
  }) async {
    if (item.sellerId == buyer.uid) {
      throw const ChatException('You cannot make an offer on your own item.');
    }
    final chatId = '${item.id}_${buyer.uid}';
    await _ensureThread(chatId: chatId, item: item, buyer: buyer);

    await sendOffer(
      chatId: chatId,
      senderId: buyer.uid,
      senderName: buyer.name,
      amount: amount,
      note: note,
    );
    return chatId;
  }

  Future<void> _ensureThread({
    required String chatId,
    required Item item,
    required UserProfile buyer,
  }) {
    return _chats.doc(chatId).set({
      'itemId': item.id,
      'itemName': item.name,
      'itemBrand': item.brand,
      'itemSize': item.size,
      'itemPrice': item.price,
      'buyerId': buyer.uid,
      'buyerName': buyer.name,
      'buyerUsername': buyer.username,
      'sellerId': item.sellerId,
      'sellerName': item.sellerName,
      'sellerUsername': item.sellerUsername,
      'participants': [buyer.uid, item.sellerId],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendOffer({
    required String chatId,
    required String senderId,
    required String senderName,
    required int amount,
    String note = '',
  }) async {
    await _messages(chatId).add({
      'senderId': senderId,
      'senderName': senderName,
      'kind': 'offer',
      'amount': amount,
      'text': note,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _touch(
      chatId,
      preview: 'Offer · ${formatPrice(amount)}',
      senderId: senderId,
    );
  }

  Future<void> sendText({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _messages(chatId).add({
      'senderId': senderId,
      'senderName': senderName,
      'kind': 'text',
      'text': trimmed,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _touch(chatId, preview: trimmed, senderId: senderId);
  }

  /// Seller accepts or declines an offer. Accepting stores the agreed price
  /// on the thread so the buyer can check out at that price.
  Future<void> respondToOffer({
    required String chatId,
    required String messageId,
    required int amount,
    required bool accept,
    required String responderId,
  }) async {
    await _messages(chatId).doc(messageId).update({
      'status': accept ? 'accepted' : 'declined',
    });
    await _chats.doc(chatId).update({
      if (accept) 'acceptedAmount': amount,
      'lastMessage':
          accept ? 'Offer accepted · ${formatPrice(amount)}' : 'Offer declined',
      'lastSenderId': responderId,
      'lastAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _touch(
    String chatId, {
    required String preview,
    required String senderId,
  }) {
    return _chats.doc(chatId).update({
      'lastMessage': preview,
      'lastSenderId': senderId,
      'lastAt': FieldValue.serverTimestamp(),
    });
  }
}
