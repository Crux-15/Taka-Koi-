import 'dart:async';
import 'package:firebase_core/firebase_core.dart';

const String offlineMessage =
    'You\'re offline. This needs a connection, so try again when you\'re back online.';

const String slowConnectionMessage =
    'The connection is too slow right now. Try again in a moment.';

/// An expected failure whose [message] is safe to show to the user,
/// e.g. "This payment was already approved."
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Turns an error into a message for the user, falling back to [fallback]
/// for anything unexpected.
String friendlyError(Object error, String fallback) {
  if (error is AppException) return error.message;
  if (error is FormatException) return error.message;
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
        return offlineMessage;
      case 'deadline-exceeded':
        return slowConnectionMessage;
      case 'permission-denied':
        return 'You can\'t do that any more. The tour may have changed, so go back and try again.';
    }
  }
  if (error is TimeoutException) return slowConnectionMessage;
  return fallback;
}
