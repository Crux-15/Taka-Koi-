import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import 'avatar_service.dart';
import '../utils/app_constants.dart';
import '../utils/offline.dart';
import '../utils/app_log.dart';

/// Handles all Firebase Authentication operations.
class AuthService {
  final FirebaseAuth      _auth    = FirebaseAuth.instance;
  final FirebaseFirestore _db      = FirebaseFirestore.instance;
  // Created on first use: on the web it needs a client ID, so building it
  // up front would break the app for everyone not using Google sign-in.
  GoogleSignIn? _googleInstance;
  GoogleSignIn get _google => _googleInstance ??= GoogleSignIn();

  // ── Stream ────────────────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      // Website: Firebase's own Google pop-up (no extra client setup needed).
      // Closing the pop-up counts as cancelling, like on Android.
      try {
        return await _auth.signInWithPopup(GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') return null;
        rethrow;
      }
    }
    try {
      await _google.signOut();
    } catch (e, s) {
      logError('signInWithGoogle', e, s);
    }
    final googleUser = await _google.signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken:     googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  // ── Email / Password ──────────────────────────────────────────────────────
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // ── Email Verification ────────────────────────────────────────────────────
  /// Emails a verification link (sent by Firebase, not by the app).
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Re-reads the account from Firebase and, if the email has just been
  /// verified, refreshes the sign-in token so the database sees it too.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null || !fresh.emailVerified) return false;
    await fresh.getIdToken(true);
    return true;
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleInstance?.signOut();
    await _auth.signOut();
  }

  // ── User Document ─────────────────────────────────────────────────────────
  /// Checks whether a Firestore user document exists for the given uid.
  Future<bool> userDocExists(String uid) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    return doc.exists;
  }

  /// Creates the initial user document after registration / first Google sign-in.
  Future<void> createUserDoc(UserModel user) async {
    await saveOrQueue(_db.collection(AppConstants.colUsers).doc(user.uid).set(user.toMap()), 'createUserDoc');
  }

  /// Fetches the user document as a [UserModel].
  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  /// Updates specific fields on the user document.
  /// Doesn't keep the screen waiting offline (see [saveOrQueue]).
  Future<void> updateUserDoc(String uid, Map<String, dynamic> data) async {
    await saveOrQueue(_db.collection(AppConstants.colUsers).doc(uid).update(data), 'updateUserDoc');
  }

  /// Keeps the bKash number you've already shared up to date for the people
  /// you shared it with (they can't read your profile).
  Future<void> updateSharedBkash(String uid, String? number) async {
    final shared = await _db
        .collection(AppConstants.colBkashRequests)
        .where('targetId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    if (shared.docs.isEmpty) return;
    final value = (number == null || number.trim().isEmpty) ? null : number.trim();
    final batch = _db.batch();
    for (final doc in shared.docs) {
      batch.update(doc.reference, {'number': value});
    }
    await saveOrQueue(batch.commit(), 'updateSharedBkash');
  }

  // ── Profile photo ─────────────────────────────────────────────────────────
  /// Saves a profile photo (shrunk, inside the database) and returns the
  /// value to store as the profile's avatarUrl. Works offline.
  Future<String> saveAvatar(String uid, Uint8List photo) => AvatarService().save(uid, photo);
}
