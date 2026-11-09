import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_exception.dart';
import 'app_log.dart';

/// How long a screen waits for the server to confirm a write.
const Duration serverConfirmWait = Duration(seconds: 3);

/// How long a transaction may take before it gives up.
const Duration transactionTimeout = Duration(seconds: 15);

/// Waits for a Firestore write to be confirmed, but not forever.
///
/// Firestore saves a write on the phone straight away and syncs it when it
/// can, but the write's future only completes once the server confirms it,
/// which never happens offline. So this waits up to [wait]:
///
/// * confirmed in time → returns true;
/// * still waiting → returns false and leaves the write to sync in the
///   background (it's already saved on the phone and shows up everywhere in
///   the app). A failure after that is logged, since its screen has closed.
///
/// A failure within [wait] (e.g. refused by the security rules) is rethrown.
Future<bool> saveOrQueue(
  Future<void> write,
  String what, {
  Duration wait = serverConfirmWait,
}) async {
  try {
    await write.timeout(wait);
    return true;
  } on TimeoutException {
    unawaited(write.catchError((Object e, StackTrace s) => logError('queued $what', e, s)));
    return false;
  }
}

/// Starts a write nobody needs to wait for (notifications, audit entries).
/// Failures are logged instead of disappearing.
void inBackground(Future<void> write, String what) {
  unawaited(write.catchError((Object e, StackTrace s) => logError(what, e, s)));
}

/// Whether the phone has any network at all (true if that can't be told).
Future<bool> isOnline() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return !results.every((r) => r == ConnectivityResult.none);
  } catch (e, s) {
    logError('connectivity check', e, s);
    return true;
  }
}

/// Throws a friendly [AppException] if the phone has no network at all.
///
/// Used before transactions (approving an expense or a payment): those have
/// to read the latest data from the server, so offline they would just spin
/// until they time out.
Future<void> requireConnection() async {
  try {
    final results = await Connectivity().checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) {
      throw const AppException(offlineMessage);
    }
  } on AppException {
    rethrow;
  } catch (e, s) {
    // If the check itself fails, let the transaction try anyway.
    logError('connectivity check', e, s);
  }
}
