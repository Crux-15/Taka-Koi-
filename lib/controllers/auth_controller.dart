import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/app_exception.dart';
import '../utils/app_log.dart';

/// [unverified]: signed in with email and password, but the email address
/// hasn't been confirmed yet. The database refuses everything except the
/// user's own profile until it is.
enum AuthStatus { initial, loading, authenticated, unverified, unauthenticated, error }

/// Controller for authentication state and operations.
class AuthController extends ChangeNotifier {
  /// The service can be swapped for a fake in tests.
  AuthController({AuthService? authService}) : _authService = authService ?? AuthService();

  final AuthService _authService;

  /// Tests and screenshots only: act as if [user] is signed in.
  @visibleForTesting
  void debugSignIn(UserModel user) {
    _user   = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  AuthStatus _status    = AuthStatus.initial;
  UserModel? _user;
  String?    _errorMessage;
  bool       _isUpdatingProfile = false; // guard: prevents router redirect during profile save
  bool       _isRegistering     = false; // guard: registration sets its own state when done

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
  bool get needsEmailVerification => _status == AuthStatus.unverified;
  bool get isLoading             => _status == AuthStatus.loading;

  /// Email address of whoever is signed in (also while unverified).
  String get signedInEmail => _authService.currentUser?.email ?? '';

  /// Listen to Firebase auth changes and keep [_user] in sync.
  void listenToAuthChanges() {
    _authService.authStateChanges.listen((firebaseUser) async {
      // Don't react to auth events while a profile update is in progress.
      // Firebase fires authStateChanges on token refresh / photoURL changes,
      // which would temporarily reset state and trigger a router redirect.
      if (_isUpdatingProfile || _isRegistering) return;

      if (firebaseUser == null) {
        _status = AuthStatus.unauthenticated;
        _user   = null;
        notifyListeners();
        _completeAuthReady(); // auth state determined: not logged in
        return;
      }
      if (!firebaseUser.emailVerified) {
        _status = AuthStatus.unverified;
        _user   = null;
        notifyListeners();
        _completeAuthReady();
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
      debugPrint('FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}');
      _setError(_googleError(e.code));
      return false;
    } catch (e, stack) {
      debugPrint('Exception during Google Sign-In: $e\n$stack');
      final msg = e.toString();
      if (msg.contains('network_error') || msg.contains('NetworkException')) {
        _setError('No internet connection. Please check your network.');
      } else if (msg.contains('sign_in_canceled')) {
        // User explicitly tapped outside or backed out of the account picker
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
        notifyListeners();
      } else {
        _setError('Google sign-in failed: $msg');
      }
      return false;
    }
  }

  // ── Email Sign-In ─────────────────────────────────────────────────────────
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading();
    try {
      final cred = await _authService.signInWithEmail(email, password);
      if (!cred.user!.emailVerified) {
        // Accounts made before real verification existed land here too.
        // Send a link now; the verify screen can resend it.
        try {
          await _authService.sendEmailVerification();
        } catch (e, s) {
          logError('signInWithEmail', e, s);
        }
        _user   = null;
        _status = AuthStatus.unverified;
        notifyListeners();
        return true;
      }
      _user   = await _authService.fetchUser(cred.user!.uid);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      return false;
    } catch (e) {
      // Catches network errors, Firestore errors during fetchUser, etc.
      _setError('Sign-in failed. Please check your connection and try again.');
      return false;
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  /// Creates the account and profile, then has Firebase email a verification
  /// link. Ends in [AuthStatus.unverified]; the app is usable once the link
  /// has been opened.
  ///
  /// Everything happens here rather than in the screen, so it finishes even
  /// if the router moves away from the registration screen part-way.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isRegistering = true;
    _setLoading();
    try {
      final cred = await _authService.registerWithEmail(email, password);
      final fbUser = cred.user!;
      try {
        await fbUser.updateDisplayName(name);
      } catch (e, s) {
        logError('register', e, s);
      }
      await _authService.createUserDoc(UserModel(
        uid:       fbUser.uid,
        name:      name,
        email:     fbUser.email ?? email,
        avatarUrl: '',
        createdAt: DateTime.now(),
      ));
      try {
        await _authService.sendEmailVerification();
      } catch (e, s) {
        logError('register', e, s);
        // They can resend from the verify screen.
      }
      _user   = null;
      _status = AuthStatus.unverified;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      return false;
    } catch (e, s) {
      logError('register', e, s);
      _setError('Could not finish creating your account. Check your connection and try again.');
      return false;
    } finally {
      _isRegistering = false;
    }
  }

  // ── Email Verification ────────────────────────────────────────────────────
  /// Resends the verification link. Returns an error message, or null.
  Future<String?> resendVerificationEmail() async {
    try {
      await _authService.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        return 'Too many emails sent. Wait a few minutes and try again.';
      }
      return _mapFirebaseError(e.code);
    } catch (e, s) {
      logError('resendVerificationEmail', e, s);
      return 'Could not send the email. Check your connection.';
    }
  }

  /// Checks whether the link has been opened. If so, loads (or creates) the
  /// profile and signs the user in properly.
  Future<bool> checkEmailVerified() async {
    try {
      final verified = await _authService.reloadAndCheckVerified();
      if (!verified) return false;
      final fbUser = _authService.currentUser!;
      var profile = await _authService.fetchUser(fbUser.uid);
      if (profile == null) {
        profile = UserModel(
          uid:       fbUser.uid,
          name:      fbUser.displayName ?? 'User',
          email:     fbUser.email ?? '',
          avatarUrl: fbUser.photoURL ?? '',
          createdAt: DateTime.now(),
        );
        await _authService.createUserDoc(profile);
      }
      _user   = profile;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e, s) {
      logError('checkEmailVerified', e, s);
      return false;
    }
  }

  // ── Profile Setup ─────────────────────────────────────────────────────────
  Future<bool> completeProfileSetup({
    required String name,
    String? bkashNumber,
    Uint8List? avatarFile,
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
        avatarUrl = await _authService.saveAvatar(fbUser.uid, avatarFile);
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
      _status = fbUser.emailVerified ? AuthStatus.authenticated : AuthStatus.unverified;
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
    Uint8List? avatarFile,
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
        final url = await _authService.saveAvatar(_user!.uid, avatarFile);
        updates['avatarUrl'] = url;
      }
      await _authService.updateUserDoc(_user!.uid, updates);
      if (bkashNumber != null && bkashNumber != _user!.bkashNumber) {
        try {
          await _authService.updateSharedBkash(_user!.uid, bkashNumber);
        } catch (e, s) {
          logError('updateProfile', e, s);
          // Saved on your profile; people you shared with keep the old one for now.
        }
      }
      _user = await _authService.fetchUser(_user!.uid);
      // status stays AuthStatus.authenticated — no redirect triggered
      _errorMessage = null;
      return true;
    } catch (e, s) {
      logError('updateProfile', e, s);
      _errorMessage = friendlyError(e, 'Update failed.');
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
    } catch (e, s) {
      logError('sendPasswordReset', e, s);
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

  String _googleError(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email already has a Taka Koi password. Sign in with email and password instead.';
      case 'user-disabled':
        return 'This account has been turned off.';
      case 'invalid-credential':
        return 'Google sign-in failed. Please try again, or sign in with email.';
      case 'popup-blocked':
      case 'web-storage-unsupported':
      case 'operation-not-supported-in-this-environment':
      case 'unauthorized-domain':
      case 'network-request-failed':
      case 'too-many-requests':
        return _mapFirebaseError(code);
      default:
        return 'Google sign-in failed. Please try again, or sign in with email.';
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'popup-blocked':
        return 'Your browser blocked the Google pop-up. Allow pop-ups for this site, or sign in with email.';
      case 'web-storage-unsupported':
      case 'operation-not-supported-in-this-environment':
        return 'Google sign-in doesn\'t work here. Please sign in with email instead.';
      case 'unauthorized-domain':
        return 'This website isn\'t allowed to sign in yet. Please try again later.';
      case 'user-not-found':    return 'No account found with this email.';
      case 'wrong-password':    return 'Incorrect password.';
      case 'email-already-in-use': return 'This email is already registered.';
      case 'weak-password':     return 'Password must be at least 6 characters.';
      case 'invalid-email':     return 'Please enter a valid email address.';
      case 'network-request-failed': return 'No internet connection.';
      case 'too-many-requests':      return 'Too many attempts. Wait a few minutes and try again.';
      case 'invalid-credential':     return 'Incorrect email or password.';
      default:                  return 'Authentication failed. Please try again.';
    }
  }
}
