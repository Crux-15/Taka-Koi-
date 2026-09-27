import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Controller for authentication state and operations.
class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status    = AuthStatus.initial;
  UserModel? _user;
  String?    _errorMessage;
  bool       _isUpdatingProfile = false; // guard: prevents router redirect during profile save

  // Completer that resolves when the first Firebase auth state is determined.
  final Completer<void> _authReadyCompleter = Completer<void>();
  bool _authStateReceived = false;

  /// Awaitable future that completes once Firebase has determined the auth state.
  /// Always use this in SplashView instead of a fixed delay.
  Future<void> get authReady => _authReadyCompleter.future;

  AuthStatus get status          => _status;
  UserModel? get user            => _user;
  String?    get errorMessage    => _errorMessage;
  bool get isAuthenticated       => _status == AuthStatus.authenticated;
  bool get isLoading             => _status == AuthStatus.loading;
  bool get isUpdatingProfile     => _isUpdatingProfile;

  /// Listen to Firebase auth changes and keep [_user] in sync.
  void listenToAuthChanges() {
    _authService.authStateChanges.listen((firebaseUser) async {
      // Don't react to auth events while a profile update is in progress.
      // Firebase fires authStateChanges on token refresh / photoURL changes,
      // which would temporarily reset state and trigger a router redirect.
      if (_isUpdatingProfile) return;

      if (firebaseUser == null) {
        _status = AuthStatus.unauthenticated;
        _user   = null;
        notifyListeners();
        _completeAuthReady(); // auth state determined: not logged in
        return;
      }
      // Try to load user document
      final userDoc = await _authService.fetchUser(firebaseUser.uid);
      if (userDoc != null) {
        _user   = userDoc;
        _status = AuthStatus.authenticated;
      } else {
        // First sign-in: user doc doesn't exist yet → needs profile setup
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
      _completeAuthReady(); // auth state determined: logged in (or needs profile)
    });
  }

  /// Safely completes the auth-ready completer exactly once.
  void _completeAuthReady() {
    if (!_authStateReceived) {
      _authStateReceived = true;
      _authReadyCompleter.complete();
    }
  }

  /// Returns true if the current Firebase user has a Firestore profile.
  Future<bool> currentUserHasProfile() async {
    final u = _authService.currentUser;
    if (u == null) return false;
    return _authService.userDocExists(u.uid);
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    _setLoading();
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
      final exists = await _authService.userDocExists(cred.user!.uid);
      if (!exists) {
        // Create default user doc from Google profile
        final u = cred.user!;
        final model = UserModel(
          uid:       u.uid,
          name:      u.displayName ?? 'User',
          email:     u.email ?? '',
          avatarUrl: u.photoURL ?? '',
          createdAt: DateTime.now(),
        );
        await _authService.createUserDoc(model);
        _user = model;
      } else {
        _user = await _authService.fetchUser(cred.user!.uid);
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Google sign-in failed.');
      return false;
    }
  }

  // ── Email Sign-In ─────────────────────────────────────────────────────────
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading();
    try {
      final cred = await _authService.signInWithEmail(email, password);
      _user   = await _authService.fetchUser(cred.user!.uid);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      return false;
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<bool> register(String email, String password) async {
    _setLoading();
    try {
      await _authService.registerWithEmail(email, password);
      // Don't set authenticated yet — they still need to complete profile setup
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      return false;
    }
  }

  /// Updates the Firebase Auth display name (called after OTP registration).
  Future<void> updateName(String name) async {
    try {
      await _authService.currentUser?.updateDisplayName(name);
    } catch (_) {}
  }

  // ── Profile Setup ─────────────────────────────────────────────────────────
  Future<bool> completeProfileSetup({
    required String name,
    String? bkashNumber,
    File?   avatarFile,
  }) async {
    _setLoading();
    try {
      final fbUser = _authService.currentUser;
      if (fbUser == null) {
        _setError('Not authenticated.');
        return false;
      }
      String avatarUrl = fbUser.photoURL ?? '';
      if (avatarFile != null) {
        avatarUrl = await _authService.uploadAvatar(fbUser.uid, avatarFile);
      }
      final model = UserModel(
        uid:          fbUser.uid,
        name:         name,
        email:        fbUser.email ?? '',
        avatarUrl:    avatarUrl,
        bkashNumber:  bkashNumber?.isNotEmpty == true ? bkashNumber : null,
        createdAt:    DateTime.now(),
      );
      await _authService.createUserDoc(model);
      _user   = model;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Profile setup failed. Please try again.');
      return false;
    }
  }

  // ── Update Profile ────────────────────────────────────────────────────────
  Future<bool> updateProfile({
    String? name,
    String? bkashNumber,
    File?   avatarFile,
  }) async {
    if (_user == null) return false;
    // Set guard flag — suppresses auth listener & keeps isAuthenticated=true.
    // Do NOT call _setLoading() here: that sets status=loading which makes
    // isAuthenticated=false, triggering a router redirect to /login.
    _isUpdatingProfile = true;
    notifyListeners(); // let profile view show its own loading spinner
    try {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (bkashNumber != null) updates['bkashNumber'] = bkashNumber;
      if (avatarFile != null) {
        final url = await _authService.uploadAvatar(_user!.uid, avatarFile);
        updates['avatarUrl'] = url;
      }
      await _authService.updateUserDoc(_user!.uid, updates);
      _user = await _authService.fetchUser(_user!.uid);
      // status stays AuthStatus.authenticated — no redirect triggered
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Update failed.';
      return false;
    } finally {
      // Always clear the flag and notify — even if an error occurred
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    _user   = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Password Reset ────────────────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setLoading() {
    _status       = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status       = AuthStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':    return 'No account found with this email.';
      case 'wrong-password':    return 'Incorrect password.';
      case 'email-already-in-use': return 'This email is already registered.';
      case 'weak-password':     return 'Password must be at least 6 characters.';
      case 'invalid-email':     return 'Please enter a valid email address.';
      case 'network-request-failed': return 'No internet connection.';
      default:                  return 'Authentication failed. Please try again.';
    }
  }
}
