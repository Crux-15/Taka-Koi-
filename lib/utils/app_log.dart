import 'package:flutter/foundation.dart';

/// Records an error the app deliberately carries on after: a notification
/// that didn't send, a background cleanup, a write that failed after its
/// screen had already closed.
///
/// These used to be swallowed by empty `catch` blocks. Now they at least
/// reach the debug console, and this is the one place to forward them to a
/// crash reporter later.
void logError(String where, Object error, [StackTrace? stack]) {
  debugPrint('[$where] $error');
  if (stack != null && kDebugMode) debugPrint(stack.toString());
}
