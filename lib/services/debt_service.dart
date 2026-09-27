import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_model.dart';
import '../models/payment_model.dart';
import '../utils/app_constants.dart';

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

  // ── Streams ───────────────────────────────────────────────────────────────
  /// All active debts where the given user OWES someone.
  /// Single-field query (no composite index needed); filters status in Dart.
  Stream<List<DebtModel>> iOweStream(String groupId, String userId) {
    return _debts(groupId)
        .where('fromUserId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => DebtModel.fromDoc(d, groupId: groupId))
            .where((d) => d.status == AppConstants.statusActive)
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
            .where((d) => d.status == AppConstants.statusActive)
            .toList());
  }

  /// All active debts in the group (for net computation).
  Stream<List<DebtModel>> allDebtsStream(String groupId) {
    return _debts(groupId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => DebtModel.fromDoc(d, groupId: groupId))
            .where((d) => d.status == AppConstants.statusActive)
            .toList());
  }

  // ── Log Payment ───────────────────────────────────────────────────────────
  Future<String> logPayment(String groupId, PaymentModel payment) async {
    final payId = _uuid.v4();
    await _payments(groupId).doc(payId).set(payment.toMap());
    return payId;
  }

  // ── Fetch Single Payment ──────────────────────────────────────────────────
  Future<PaymentModel?> fetchPayment(String groupId, String paymentId) async {
    final doc = await _payments(groupId).doc(paymentId).get();
    if (!doc.exists) return null;
    return PaymentModel.fromDoc(doc, groupId: groupId);
  }

  /// Real-time stream for a single payment document.
  Stream<PaymentModel?> paymentStream(String groupId, String paymentId) {
    return _payments(groupId).doc(paymentId).snapshots().map(
      (doc) => doc.exists ? PaymentModel.fromDoc(doc, groupId: groupId) : null,
    );
  }

  // ── Resubmit Payment ──────────────────────────────────────────────────────
  Future<void> resubmitPayment(
    String groupId,
    String paymentId,
    Map<String, dynamic> updates,
  ) async {
    await _payments(groupId).doc(paymentId).update({
      ...updates,
      'status':        AppConstants.statusPending,
      'rejectionNote': null,
      'resubmittedAt': Timestamp.now(),
    });
  }

  // ── Approve Payment ───────────────────────────────────────────────────────
  Future<void> approvePayment(String groupId, PaymentModel payment) async {
    final batch = _db.batch();
    final now   = DateTime.now();

    // 1. Mark payment as approved
    batch.update(
      _payments(groupId).doc(payment.paymentId),
      {'status': AppConstants.statusApproved, 'approvedAt': Timestamp.fromDate(now)},
    );

    // 2. Reduce remainingAmount on the debt
    final debtSnap = await _debts(groupId).doc(payment.debtId).get();
    if (debtSnap.exists) {
      final debt = DebtModel.fromDoc(debtSnap, groupId: groupId);
      final newRemaining = debt.remainingAmount - payment.amount;
      final newStatus = newRemaining <= 0
          ? AppConstants.statusSettled
          : AppConstants.statusActive;

      batch.update(
        _debts(groupId).doc(payment.debtId),
        {
          'remainingAmount': newRemaining.clamp(0, double.infinity),
          'status':          newStatus,
          if (newStatus == AppConstants.statusSettled)
            'settledAt': Timestamp.fromDate(now),
        },
      );
    }

    await batch.commit();
  }

  // ── Reject Payment ────────────────────────────────────────────────────────
  Future<void> rejectPayment(String groupId, String paymentId, String note) async {
    await _payments(groupId).doc(paymentId).update({
      'status':        AppConstants.statusRejected,
      'rejectionNote': note,
    });
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
  final net = <String, double>{};

  for (final debt in iOwe) {
    net[debt.toUserId] = (net[debt.toUserId] ?? 0) + debt.remainingAmount;
  }
  for (final debt in owedToMe) {
    net[debt.fromUserId] = (net[debt.fromUserId] ?? 0) - debt.remainingAmount;
  }

  return net;
}
