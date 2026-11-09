import 'package:cloud_firestore/cloud_firestore.dart';

/// The signed-in user's saved ("closet") item ids.
/// Stored as an array on the profile document: users/{uid}.savedItems
class SavedService {
  SavedService._();
  static final SavedService instance = SavedService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Set<String>> watch(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
        final raw = doc.data()?['savedItems'];
        if (raw is! List) return <String>{};
        return raw.whereType<String>().toSet();
      });

  Future<void> setSaved({
    required String uid,
    required String itemId,
    required bool saved,
  }) {
    return _db.collection('users').doc(uid).update({
      'savedItems': saved
          ? FieldValue.arrayUnion([itemId])
          : FieldValue.arrayRemove([itemId]),
    });
  }
}
