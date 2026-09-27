import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../utils/app_constants.dart';

/// Handles all Firebase Authentication operations.
class AuthService {
  final FirebaseAuth      _auth    = FirebaseAuth.instance;
  final FirebaseFirestore _db      = FirebaseFirestore.instance;
  final FirebaseStorage   _storage = FirebaseStorage.instance;
  final GoogleSignIn      _google  = GoogleSignIn();

  // ── Stream ────────────────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
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

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _google.signOut();
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
    await _db.collection(AppConstants.colUsers).doc(user.uid).set(user.toMap());
  }

  /// Fetches the user document as a [UserModel].
  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  /// Streams the user document for real-time updates.
  Stream<UserModel?> userStream(String uid) {
    return _db.collection(AppConstants.colUsers).doc(uid).snapshots().map(
      (doc) => doc.exists ? UserModel.fromDoc(doc) : null,
    );
  }

  /// Updates specific fields on the user document.
  Future<void> updateUserDoc(String uid, Map<String, dynamic> data) {
    return _db.collection(AppConstants.colUsers).doc(uid).update(data);
  }

  // ── Avatar Upload ─────────────────────────────────────────────────────────
  Future<String> uploadAvatar(String uid, File imageFile) async {
    final ref = _storage.ref('avatars/$uid.jpg');
    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }
}
