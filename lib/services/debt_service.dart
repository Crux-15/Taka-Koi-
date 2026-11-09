import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_model.dart';
import '../models/payment_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_exception.dart';
import '../utils/money.dart';
import '../utils/offline.dart';
import 'offline_actions.dart';

/// What happened when a receiver confirmed a payment, decided in a transaction.
class _PaymentApproval {
  final String? error;
  final int     remainingCents;
  const _PaymentApproval.ok(this.remainingCents) : error = null;
  const _PaymentApproval.failed(this.error) : remainingCents = 0;
}

/// Handles debt queries and payment settlement in Firestore.
class DebtService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final Uuid              _uuid = const Uuid();

  CollectionReference _debts(String groupId) => _db
      .collection(AppConstants.colGroups)
      .doc(groupId)
      .collection(AppConstants.colDebts);

  CollectionReference _payments(String groupId) => _db
      .collection(AppConstants.colGroups)
      .doc(groupId)
      .collection(AppConstants.colPayments);

  DocumentReference _group(String groupId) =>
      _db.collection(AppConstants.colGroups).doc(groupId);

  // ── Streams ───────────────────────────────────────────────────────────────
  /// All active debts where the given user OWES someone.
  /// Single-field query (no composite index needed); filters status in Dart.
  Stream<List<DebtModel>> iOweStream(String groupId, String userId) {
    return _debts(groupId)
        .where('fromUserId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => DebtModel.fromDoc(d, groupId: groupId))
            .where((d) => d.isOpen)
            .toList());
  }

  /// All active debts where someone owes the given user.
  /// Single-field query (no composite index needed); filters status in Dart.
  Stream<List<DebtModel>> owedToMeStream(String groupId, String userId) {
    return _debts(groupId)
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => DebtModel.fromDoc(d, groupId: groupId))
            .where((d) => d.isOpen)
            .toList());
  }

  /// Every payment logged in a tour (one-off read, for past tours).
  Future<List<PaymentModel>> fetchAllPayments(String groupId) async {
    final snap = await _payments(groupId).get();
    return snap.docs.map((d) => PaymentModel.fromDoc(d, groupId: groupId)).toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  }

  /// Every debt of a tour, settled or not (one-off read, for past tours).
  Future<List<DebtModel>> fetchAllDebts(String groupId) async {
    final snap = await _debts(groupId).get();
    return snap.docs.map((d) => DebtModel.fromDoc(d, groupId: groupId)).toList();
  }

  // ── Log Payment ───────────────────────────────────────────────────────────
  /// Settling up counts as tour activity, so it keeps an idle tour from
  /// being ended automatically.
  ///
  /// Works offline: returns `synced: false` if the server hasn't confirmed
  /// within a few seconds (it's saved on the phone and syncs later).
  Future<({String id, bool synced})> logPayment(String groupId, PaymentModel payment) async {
    final payId = _uuid.v4();
    final batch = _db.batch();
    batch.set(_payments(groupId).doc(payId), payment.toMap());
    batch.update(_group(groupId), {'lastActivityAt': FieldValue.serverTimestamp()});
    final synced = await saveOrQueue(batch.commit(), 'log payment');
    return (id: payId, synced: synced);
  }

  // ── Fetch Single Payment ──────────────────────────────────────────────────
  Future<PaymentModel?> fetchPayment(String groupId, String paymentId) async {
    final doc = await _payments(groupId).doc(paymentId).get();
    if (!doc.exists) return null;
    return PaymentModel.fromDoc(doc, groupId: groupId);
  }

  // ── Approve Payment ───────────────────────────────────────────────────────
  /// Confirms a pending payment and reduces its debt in the same write.
  ///
  /// The payment must still be pending, so tapping Confirm twice (or on two
  /// devices) can't reduce the debt twice. A payment bigger than what's still
  /// owed is refused rather than silently clamped, so no money goes missing.
  ///
  /// Works offline too (see [decideAndWrite]); the security rules check the
  /// debt went down by exactly this payment when it syncs. Returns what's
  /// still owed afterwards and whether it was queued.
  Future<({double remaining, bool queued})> approvePayment(String groupId, String paymentId) async {
    final payRef = _payments(groupId).doc(paymentId);

    // Which debt it's for never changes, so look it up first (server or saved copy).
    DocumentSnapshot first;
    try {
      first = await payRef.get();
    } on FirebaseException {
      first = await payRef.get(const GetOptions(source: Source.cache));
    }
    if (!first.exists) throw const AppException('This payment no longer exists.');
    final debtRef = _debts(groupId).doc(PaymentModel.fromDoc(first, groupId: groupId).debtId);

    final run = await decideAndWrite<_PaymentApproval>(_db, [payRef, debtRef], (docs, w) {
      final paySnap  = docs[0];
      final debtSnap = docs[1];
      if (!paySnap.exists) return const _PaymentApproval.failed('This payment no longer exists.');
      final payment = PaymentModel.fromDoc(paySnap, groupId: groupId);
      if (!payment.isPending) return _PaymentApproval.failed('This payment was already ${payment.status}.');
      if (!debtSnap.exists) {
        return const _PaymentApproval.failed(
          'The debt this payment was for no longer exists. Reject the payment instead.',
        );
      }
      final debt = DebtModel.fromDoc(debtSnap, groupId: groupId);

      final remainingCents = debt.isActive ? debt.remainingCents : 0;
      final payCents       = Money.toCents(payment.amount);
      if (payCents <= 0) return const _PaymentApproval.failed('This payment has no amount. Reject it instead.');
      if (payCents > remainingCents) {
        return _PaymentApproval.failed(
          'This payment (${Money.format(payCents)}) is more than the '
          '${Money.format(remainingCents)} still owed. Reject it so it can be corrected.',
        );
      }

      final newCents = remainingCents - payCents;
      final now      = Timestamp.now();
      w.update(payRef, {'status': AppConstants.statusApproved, 'approvedAt': now});
      w.update(debtRef, {
        'remainingAmount': Money.fromCents(newCents),
        'status':          newCents == 0 ? AppConstants.statusSettled : AppConstants.statusActive,
        if (newCents == 0) 'settledAt': now,
      });
      w.update(_group(groupId), {'lastActivityAt': FieldValue.serverTimestamp()});
      return _PaymentApproval.ok(newCents);
    });

    if (run.result.error != null) throw AppException(run.result.error!);
    return (remaining: Money.fromCents(run.result.remainingCents), queued: run.queued);
  }

  // ── Reject Payment ────────────────────────────────────────────────────────
  Future<void> rejectPayment(String groupId, String paymentId, String note) async {
    await saveOrQueue(
      _payments(groupId).doc(paymentId).update({
        'status':        AppConstants.statusRejected,
        'rejectionNote': note,
      }),
      'reject payment',
    );
  }

  // ── Pending Payments (for receiver to approve) ────────────────────────────
  /// Uses single-field query only (no composite index needed); filters and sorts in Dart.
  Stream<List<PaymentModel>> pendingPaymentsForMeStream(String groupId, String userId) {
    return _payments(groupId)
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => PaymentModel.fromDoc(d, groupId: groupId))
              .where((p) => p.status == AppConstants.statusPending)
              .toList();
          list.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
          return list;
        });
  }

  /// Payments I submitted that are pending or rejected.
  /// Uses single-field query (no composite index needed); sorts in Dart.
  Stream<List<PaymentModel>> myPaymentsStream(String groupId, String userId) {
    return _payments(groupId)
        .where('fromUserId', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => PaymentModel.fromDoc(d, groupId: groupId)).toList();
          list.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
          return list;
        });
  }
}

/// Helper: computes net payable amounts from raw debt lists (client-side).
/// Returns a map of userId → net amount (positive = I owe them, negative = they owe me).
Map<String, double> computeNetDebts({
  required List<DebtModel> iOwe,
  required List<DebtModel> owedToMe,
}) {
  // Summed in whole cents so balances that cancel out come to exactly zero.
  final net = <String, int>{};

  for (final debt in iOwe) {
    net[debt.toUserId] = (net[debt.toUserId] ?? 0) + debt.remainingCents;
  }
  for (final debt in owedToMe) {
    net[debt.fromUserId] = (net[debt.fromUserId] ?? 0) - debt.remainingCents;
  }

  return net.map((uid, cents) => MapEntry(uid, Money.fromCents(cents)));
}
