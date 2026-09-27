import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/expense_model.dart';
import '../models/debt_model.dart';
import '../utils/app_constants.dart';

/// Handles all Firestore CRUD for expenses and the resulting debt creation.
class ExpenseService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final Uuid              _uuid = const Uuid();

  CollectionReference _expenses(String groupId) => _db
      .collection(AppConstants.colGroups)
      .doc(groupId)
      .collection(AppConstants.colExpenses);

  CollectionReference _debts(String groupId) => _db
      .collection(AppConstants.colGroups)
      .doc(groupId)
      .collection(AppConstants.colDebts);

  CollectionReference _auditLog(String groupId) => _db
      .collection(AppConstants.colGroups)
      .doc(groupId)
      .collection(AppConstants.colAuditLog);

  // ── Log Expense ──────────────────────────────────────────────────────────
  /// If the expense is solo (only the logger in splits), auto-approve and
  /// create debts immediately.
  /// If others are in the split, set status=pending and populate approvals map.
  Future<String> logExpense(String groupId, ExpenseModel expense) async {
    final expId  = _uuid.v4();
    final now    = DateTime.now();
    final batch  = _db.batch();
    final groupRef = _db.collection(AppConstants.colGroups).doc(groupId);

    // Non-logger split members — they need to approve
    final approvalMembers = expense.splits.keys
        .where((uid) => uid != expense.loggedBy)
        .toList();

    final isSolo = approvalMembers.isEmpty;

    final Map<String, dynamic> expMap = {
      ...expense.toMap(),
      'status':    isSolo ? AppConstants.statusApproved : AppConstants.statusPending,
      if (isSolo) 'approvedAt': Timestamp.fromDate(now),
      'approvals': isSolo
          ? <String, String>{}
          : {for (final uid in approvalMembers) uid: AppConstants.statusPending},
      'rejectionReasons': <String, String>{},
    };

    batch.set(_expenses(groupId).doc(expId), expMap);

    if (isSolo) {
      // Create debts immediately for solo (no debt actually — logger owes nobody)
      batch.update(groupRef, {'lastActivityAt': Timestamp.fromDate(now)});
    } else {
      batch.update(groupRef, {'lastActivityAt': Timestamp.fromDate(now)});
    }

    await batch.commit();

    // Non-critical audit log
    try {
      await _writeAuditLog(
        groupId:     groupId,
        action:      isSolo ? AppConstants.statusApproved : AppConstants.statusPending,
        actorId:     expense.loggedBy,
        referenceId: expId,
        dataJson:    jsonEncode({'expenseId': expId, 'amount': expense.amount, 'isSolo': isSolo}),
      );
    } catch (_) {}

    return expId;
  }

  // ── Approve Expense (one member) ────────────────────────────────────────
  /// Called when a split member approves the expense.
  /// If all members have now approved, auto-finalises: sets status=approved,
  /// creates all debt records, and returns true (caller sends "fully approved" notif).
  Future<bool> approveExpense(String groupId, String expenseId, String userId) async {
    final expDoc  = _expenses(groupId).doc(expenseId);
    final expSnap = await expDoc.get();
    if (!expSnap.exists) return false;

    final expense = ExpenseModel.fromDoc(expSnap, groupId: groupId);

    // Update this member's approval
    final newApprovals = Map<String, String>.from(expense.approvals);
    newApprovals[userId] = AppConstants.statusApproved;

    final allDone = newApprovals.values.every((v) => v == AppConstants.statusApproved);

    if (allDone) {
      // All approved → finalise
      final now   = DateTime.now();
      final batch = _db.batch();

      batch.update(expDoc, {
        'approvals':  newApprovals,
        'status':     AppConstants.statusApproved,
        'approvedAt': Timestamp.fromDate(now),
      });

      // Create debt records — each non-logger split member owes the logger
      for (final entry in expense.splits.entries) {
        if (entry.key == expense.loggedBy) continue;
        final debtId = _uuid.v4();
        final debt   = DebtModel(
          debtId:          debtId,
          groupId:         groupId,
          fromUserId:      entry.key,
          fromUserName:    entry.value.name,
          toUserId:        expense.loggedBy,
          toUserName:      expense.loggedByName,
          sourceExpenseId: expenseId,
          originalAmount:  entry.value.amount,
          remainingAmount: entry.value.amount,
          status:          AppConstants.statusActive,
          createdAt:       now,
        );
        batch.set(_debts(groupId).doc(debtId), debt.toMap());
      }

      // Mark hasApprovedExpense for all split members
      final memberUpdates = <String, dynamic>{};
      for (final uid in expense.splits.keys) {
        memberUpdates['members.$uid.hasApprovedExpense'] = true;
      }
      batch.update(
        _db.collection(AppConstants.colGroups).doc(groupId),
        {...memberUpdates, 'lastActivityAt': Timestamp.fromDate(now)},
      );

      await batch.commit();
      return true; // signals "all approved"
    } else {
      // Partial approval
      await expDoc.update({'approvals': newApprovals});
      return false;
    }
  }

  // ── Reject Expense (one member) ─────────────────────────────────────────
  Future<void> rejectExpense(
    String groupId,
    String expenseId,
    String userId,
    String reason,
  ) async {
    final expDoc  = _expenses(groupId).doc(expenseId);
    final expSnap = await expDoc.get();
    if (!expSnap.exists) return;

    final expense = ExpenseModel.fromDoc(expSnap, groupId: groupId);
    final newApprovals = Map<String, String>.from(expense.approvals);
    final newReasons   = Map<String, String>.from(expense.rejectionReasons);

    newApprovals[userId] = AppConstants.statusRejected;
    if (reason.trim().isNotEmpty) {
      newReasons[userId] = reason.trim();
    }

    await expDoc.update({
      'approvals':        newApprovals,
      'rejectionReasons': newReasons,
    });
  }

  // ── Request Again (logger re-requests one rejected member) ──────────────
  Future<void> requestAgain(String groupId, String expenseId, String userId) async {
    final expDoc  = _expenses(groupId).doc(expenseId);
    final expSnap = await expDoc.get();
    if (!expSnap.exists) return;

    final expense      = ExpenseModel.fromDoc(expSnap, groupId: groupId);
    final newApprovals = Map<String, String>.from(expense.approvals);
    final newReasons   = Map<String, String>.from(expense.rejectionReasons);

    newApprovals[userId] = AppConstants.statusPending;
    newReasons.remove(userId);

    await expDoc.update({
      'approvals':        newApprovals,
      'rejectionReasons': newReasons,
    });
  }

  // ── Edit Split Amount + Request Again (custom split only) ───────────────
  /// Adjusts the target member's share to [newAmount].
  /// The difference is absorbed by the logger's own share.
  Future<void> editAndRequestAgain(
    String groupId,
    String expenseId,
    String targetUserId,
    double newAmount,
  ) async {
    final expDoc  = _expenses(groupId).doc(expenseId);
    final expSnap = await expDoc.get();
    if (!expSnap.exists) return;

    final expense = ExpenseModel.fromDoc(expSnap, groupId: groupId);

    final oldAmount    = expense.splits[targetUserId]?.amount ?? 0.0;
    final diff         = newAmount - oldAmount; // positive = target pays more, logger less

    // Rebuild splits map with updated amounts
    final newSplits = Map<String, SplitEntry>.from(expense.splits);

    // Update target member's share
    newSplits[targetUserId] = SplitEntry(
      userId: targetUserId,
      name:   expense.splits[targetUserId]!.name,
      amount: newAmount,
    );

    // Adjust logger's share by the opposite of the diff
    final loggerEntry = newSplits[expense.loggedBy];
    if (loggerEntry != null) {
      final newLoggerAmount = (loggerEntry.amount - diff).clamp(0.0, expense.amount);
      newSplits[expense.loggedBy] = SplitEntry(
        userId: expense.loggedBy,
        name:   loggerEntry.name,
        amount: newLoggerAmount,
      );
    }

    final newApprovals = Map<String, String>.from(expense.approvals);
    final newReasons   = Map<String, String>.from(expense.rejectionReasons);
    newApprovals[targetUserId] = AppConstants.statusPending;
    newReasons.remove(targetUserId);

    await expDoc.update({
      'splits':           newSplits.map((k, v) => MapEntry(k, v.toMap())),
      'approvals':        newApprovals,
      'rejectionReasons': newReasons,
    });
  }

  // ── Delete Expense (also removes associated debts) ────────────────────
  Future<void> deleteExpense(String groupId, String expenseId) async {
    final batch = _db.batch();
    batch.delete(_expenses(groupId).doc(expenseId));

    final debtsQuery = await _debts(groupId)
        .where('sourceExpenseId', isEqualTo: expenseId)
        .get();
    for (final doc in debtsQuery.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Streams ───────────────────────────────────────────────────────────────
  /// All APPROVED expenses for the group home feed.
  /// No composite index needed — filters by single field, sorts in Dart.
  Stream<List<ExpenseModel>> approvedExpensesStream(String groupId) {
    return _expenses(groupId)
        .where('status', isEqualTo: AppConstants.statusApproved)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => ExpenseModel.fromDoc(d, groupId: groupId))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// All expenses logged by a specific user (approved + pending) — for My Expenses.
  Stream<List<ExpenseModel>> myExpensesStream(String groupId, String userId) {
    return _expenses(groupId)
        .where('loggedBy', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => ExpenseModel.fromDoc(d, groupId: groupId))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Expenses where this user is a split member with a PENDING approval.
  /// Used to show the approver what they need to act on.
  Stream<List<ExpenseModel>> pendingApprovalForMeStream(String groupId, String userId) {
    // Firestore can't query inside a map field easily without indexes.
    // Fetch all pending expenses in group and filter in Dart.
    return _expenses(groupId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .snapshots()
        .map((s) {
          return s.docs
              .map((d) => ExpenseModel.fromDoc(d, groupId: groupId))
              .where((e) => e.approvals[userId] == AppConstants.statusPending)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
  }

  /// Single-document real-time stream — used by ExpenseDetailView.
  Stream<ExpenseModel> expenseStream(String groupId, String expenseId) {
    return _expenses(groupId).doc(expenseId).snapshots().map(
      (doc) => ExpenseModel.fromDoc(doc, groupId: groupId),
    );
  }

  // ── Audit Log (non-critical) ──────────────────────────────────────────
  Future<void> _writeAuditLog({
    required String groupId,
    required String action,
    required String actorId,
    required String referenceId,
    required String dataJson,
  }) async {
    final hash = sha256.convert(utf8.encode(dataJson)).toString();
    await _auditLog(groupId).add({
      'action':      action,
      'actorId':     actorId,
      'referenceId': referenceId,
      'dataHash':    hash,
      'timestamp':   Timestamp.now(),
    });
  }
}
