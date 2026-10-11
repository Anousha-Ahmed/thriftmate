import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart';

/// A friendly, user-readable error thrown by [AuthService].
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// All authentication + user-profile logic lives here (not in the UI).
///
/// Firestore structure:
///   users/{uid}            -> name, username, email, role, createdAt
///   usernames/{username}   -> { uid }   (this doc's existence = username taken)
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;

  /// Usernames are case-insensitive: "Ali_01" and "ali_01" are the same.
  static String normalizeUsername(String username) =>
      username.trim().toLowerCase();

  // ---------------------------------------------------------------------------
  // Username availability
  // ---------------------------------------------------------------------------
  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _db
        .collection('usernames')
        .doc(normalizeUsername(username))
        .get()
        .timeout(const Duration(seconds: 8));
    return !doc.exists;
  }

  // ---------------------------------------------------------------------------
  // Email + password
  // ---------------------------------------------------------------------------
  Future<void> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    final uname = normalizeUsername(username);

    if (!await isUsernameAvailable(uname)) {
      throw const AuthException('Username is already taken');
    }

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }

    try {
      await _createProfile(
        uid: cred.user!.uid,
        name: name.trim(),
        username: uname,
        email: email.trim(),
        role: role,
      );
      await cred.user!.updateDisplayName(name.trim());
    } catch (e) {
      // Roll back so we never leave an account without a profile.
      try {
        await cred.user!.delete();
      } catch (_) {}
      if (e is AuthException) rethrow;
      throw const AuthException(
          'Could not create your profile. Please try again.');
    }
  }

  Future<User> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------
  /// Chrome/web  -> Firebase popup.
  /// Android/iOS -> native Google account picker (google_sign_in) once the
  ///                Web client ID is set in AppConfig; otherwise falls back to
  ///                Firebase's browser-based Google flow.
  Future<User> signInWithGoogle() async {
    try {
      final UserCredential cred;
      if (kIsWeb) {
        cred = await _auth.signInWithPopup(GoogleAuthProvider()..addScope('email'));
      } else if (AppConfig.hasGoogleServerClientId) {
        cred = await _signInWithGoogleNative();
      } else {
        cred = await _auth
            .signInWithProvider(GoogleAuthProvider()..addScope('email'));
      }
      return cred.user!;
    } on GoogleSignInException catch (e) {
      if (e.code.name.toLowerCase().contains('cancel')) {
        throw const AuthException('Google sign-in was cancelled');
      }
      throw AuthException(
          'Google sign-in failed (${e.code.name}). Check the SHA-1 and Web client ID in Firebase.');
    } on FirebaseAuthException catch (e) {
      const cancelled = {
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-canceled',
        'canceled',
      };
      if (cancelled.contains(e.code)) {
        throw const AuthException('Google sign-in was cancelled');
      }
      throw AuthException(_mapError(e));
    }
  }


  Future<UserCredential> _signInWithGoogleNative() async {
    final googleSignIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await googleSignIn.initialize(
        serverClientId: AppConfig.googleServerClientId,
      );
      _googleInitialized = true;
    }
    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException(
          'Could not get a Google token. Check the Web client ID.');
    }
    return _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile (used by Google users who still need to pick a username/role)
  // ---------------------------------------------------------------------------
  Future<bool> profileExists(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<void> completeProfile({
    required String name,
    required String username,
    required String role,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('You are signed out. Please log in again.');
    }
    await _createProfile(
      uid: user.uid,
      name: name.trim(),
      username: normalizeUsername(username),
      email: user.email ?? '',
      role: role,
    );
  }

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return UserProfile.fromMap(uid, data);
  }

  /// True when the account can log in with email + password. Accounts that
  /// only use Google sign-in have no password to reset.
  bool get hasPasswordLogin =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> signOut() async {
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Reserves the username and writes the profile in ONE transaction, so two
  /// people can never end up with the same username (even at the same moment).
  Future<void> _createProfile({
    required String uid,
    required String name,
    required String username,
    required String email,
    required String role,
  }) async {
    final usernameRef = _db.collection('usernames').doc(username);
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(usernameRef);
      if (snap.exists) {
        throw const AuthException('Username is already taken');
      }
      tx.set(usernameRef, {'uid': uid});
      tx.set(userRef, {
        'uid': uid,
        'name': name,
        'username': username,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using another sign-in method.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
