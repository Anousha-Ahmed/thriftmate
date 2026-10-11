/// A user's profile as stored in Firestore: users/{uid}.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
  });

  final String uid;
  final String name; // full name (display only, can repeat between users)
  final String username; // unique public handle, stored lowercase
  final String email;
  final String role; // 'buyer' or 'seller'

  /// "Anousha Ahmad" -> "Anousha". Falls back to the username.
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return username;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get roleLabel => role == 'seller' ? 'Seller' : 'Buyer';

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      name: (data['name'] ?? '') as String,
      username: (data['username'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      role: (data['role'] ?? 'buyer') as String,
    );
  }
}
