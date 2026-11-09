import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import '../models/expense_model.dart';
import '../models/debt_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_exception.dart';
import '../utils/money.dart';
import '../utils/offline.dart';
import 'offline_actions.dart';

/// Result of one member's approval, decided inside a transaction.
enum _ApprovalOutcome { recorded, finalised, notFound, alreadyFinal, notInSplit }

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

  CollectionReference _payments(String groupId) => _db
      .collection(AppConstants.colGroups)
      .doc(groupId)
      .collection(AppConstants.colPayments);

  /// One debt per (expense, member). Because the id is fixed, finalising the
  /// same expense twice can never create a second copy of a debt.
  static String debtIdFor(String expenseId, String userId) => '${expenseId}_$userId';

  CollectionReference _auditLog(String groupId) => _db
      .collection(AppConstants.colGroups)
      .doc(groupId)
      .collection(AppConstants.colAuditLog);

  // ── Log Expense ──────────────────────────────────────────────────────────
  /// If the expense is solo (only the logger in splits), auto-approve and
  /// create debts immediately.
  /// If others are in the split, set status=pending and populate approvals map.
  ///
  /// Works offline: returns `synced: false` if the server hasn't confirmed
  /// the save within a few seconds. It's already saved on the phone and
  /// Firestore sends it once the connection is back.
  Future<({String id, bool synced})> logExpense(String groupId, ExpenseModel expense) async {
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

    // Server clock only: the security rules refuse any other lastActivityAt.
    // A shared expense also marks the logger as involved in money, which stops
    // the admin removing them (each member can only set their own flag).
    batch.update(groupRef, {
      'lastActivityAt': FieldValue.serverTimestamp(),
      if (!isSolo) 'members.${expense.loggedBy}.hasApprovedExpense': true,
    });

    final synced = await saveOrQueue(batch.commit(), 'log expense');

    // Non-critical audit log
    inBackground(
      _writeAuditLog(
        groupId:     groupId,
        action:      isSolo ? AppConstants.statusApproved : AppConstants.statusPending,
        actorId:     expense.loggedBy,
        referenceId: expId,
        dataJson:    jsonEncode({'expenseId': expId, 'amount': expense.amount, 'isSolo': isSolo}),
      ),
      'audit log',
    );

    return (id: expId, synced: synced);
  }

  // ── Approve Expense (one member) ────────────────────────────────────────
  /// A split member approves their share. When it's the last approval it also
  /// finalises the expense: status=approved and the debt records, in one go,
  /// so it can only ever happen once.
  ///
  /// Works offline too (see [decideAndWrite]): the approval is queued and the
  /// security rules check it when it syncs. Returns whether this finalised the
  /// expense and whether it was queued.
  Future<({bool finalised, bool queued})> approveExpense(String groupId, String expenseId, String userId) async {
    final expDoc   = _expenses(groupId).doc(expenseId);
    final groupRef = _db.collection(AppConstants.colGroups).doc(groupId);

    final run = await decideAndWrite<_ApprovalOutcome>(_db, [expDoc, groupRef], (docs, w) {
      final expSnap   = docs[0];
      final groupSnap = docs[1];
      if (!expSnap.exists) return _ApprovalOutcome.notFound;

      final expense = ExpenseModel.fromDoc(expSnap, groupId: groupId);
      if (!expense.isPending) return _ApprovalOutcome.alreadyFinal;

      final myStatus = expense.approvals[userId];
      if (myStatus == null) return _ApprovalOutcome.notInSplit;
      if (myStatus == AppConstants.statusApproved) return _ApprovalOutcome.recorded;

      final newApprovals = Map<String, String>.from(expense.approvals)
        ..[userId] = AppConstants.statusApproved;
      final allDone = newApprovals.values.every((v) => v == AppConstants.statusApproved);

      // Approving marks you as involved in money, which stops the admin
      // removing you. You can only ever set your own flag.
      final groupData = (groupSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final members   = groupData['members'] as Map<String, dynamic>? ?? {};
      final inGroup   = groupSnap.exists && members.containsKey(userId);

      if (!allDone) {
        // Only touch this member's entry so other approvals are never overwritten.
        w.update(expDoc, {'approvals.$userId': AppConstants.statusApproved});
        if (inGroup) w.update(groupRef, {'members.$userId.hasApprovedExpense': true});
        return _ApprovalOutcome.recorded;
      }

      final now = DateTime.now();
      w.update(expDoc, {
        'approvals.$userId': AppConstants.statusApproved,
        'status':            AppConstants.statusApproved,
        'approvedAt':        Timestamp.fromDate(now),
      });
      _writeDebts(w, groupId, expense, now);
      if (inGroup) {
        w.update(groupRef, {
          'lastActivityAt':                     FieldValue.serverTimestamp(),
          'members.$userId.hasApprovedExpense': true,
        });
      }
      return _ApprovalOutcome.finalised;
    });

    switch (run.result) {
      case _ApprovalOutcome.finalised:
        return (finalised: true, queued: run.queued);
      case _ApprovalOutcome.recorded:
        return (finalised: false, queued: run.queued);
      case _ApprovalOutcome.notFound:
        throw const AppException('This expense no longer exists.');
      case _ApprovalOutcome.alreadyFinal:
        throw const AppException('This expense has already been finalised.');
      case _ApprovalOutcome.notInSplit:
        throw const AppException('You\'re not part of this split.');
    }
  }

  /// Each non-logger split member owes the logger their share.
  void _writeDebts(ActionWriter w, String groupId, ExpenseModel expense, DateTime now) {
    for (final entry in expense.splits.entries) {
      if (entry.key == expense.loggedBy) continue;
      final cents = Money.toCents(entry.value.amount);
      if (cents <= 0) continue; // nothing owed, so no debt to settle
      final debtId = debtIdFor(expense.expenseId, entry.key);
      w.set(_debts(groupId).doc(debtId), DebtModel(
        debtId:          debtId,
        groupId:         groupId,
        fromUserId:      entry.key,
        fromUserName:    entry.value.name,
        toUserId:        expense.loggedBy,
        toUserName:      expense.loggedByName,
        sourceExpenseId: expense.expenseId,
        originalAmount:  Money.fromCents(cents),
        remainingAmount: Money.fromCents(cents),
        status:          AppConstants.statusActive,
        createdAt:       now,
      ).toMap());
    }
  }

  /// Approvals made offline can all arrive without any of them being "last"
  /// (each phone saw someone else still pending). Then everyone has approved
  /// but nobody finalised it. The logger's app calls this to finish the job:
  /// online only, as a transaction, so it happens exactly once.
  Future<bool> finaliseIfAllApproved(String groupId, String expenseId) async {
    if (!await isOnline()) return false;
    final expDoc   = _expenses(groupId).doc(expenseId);
    final groupRef = _db.collection(AppConstants.colGroups).doc(groupId);
    return _db.runTransaction<bool>(timeout: transactionTimeout, (tx) async {
      final snap = await tx.get(expDoc);
      if (!snap.exists) return false;
      final expense = ExpenseModel.fromDoc(snap, groupId: groupId);
      if (!expense.isPending || expense.approvals.isEmpty) return false;
      if (!expense.approvals.values.every((v) => v == AppConstants.statusApproved)) return false;
      final now = DateTime.now();
      tx.update(expDoc, {'status': AppConstants.statusApproved, 'approvedAt': Timestamp.fromDate(now)});
      final w = _TxWriterProxy(tx);
      _writeDebts(w, groupId, expense, now);
      tx.update(groupRef, {'lastActivityAt': FieldValue.serverTimestamp()});
      return true;
    });
  }

  // ── Reject Expense (one member) ─────────────────────────────────────────
  /// Returns true if it was queued offline rather than confirmed.
  Future<bool> rejectExpense(String groupId, String expenseId, String userId, String reason) async {
    final expDoc = _expenses(groupId).doc(expenseId);
    final run = await decideAndWrite<String?>(_db, [expDoc], (docs, w) {
      final snap = docs[0];
      if (!snap.exists) return 'This expense no longer exists.';
      final expense = ExpenseModel.fromDoc(snap, groupId: groupId);
      if (!expense.isPending) return 'This expense has already been finalised.';
      if (!expense.approvals.containsKey(userId)) return 'You\'re not part of this split.';
      w.update(expDoc, {
        'approvals.$userId': AppConstants.statusRejected,
        if (reason.trim().isNotEmpty) 'rejectionReasons.$userId': reason.trim(),
      });
      return null;
    });
    if (run.result != null) throw AppException(run.result!);
    return run.queued;
  }

  // ── Request Again (logger re-requests one rejected member) ──────────────
  /// Returns true if it was queued offline rather than confirmed.
  Future<bool> requestAgain(String groupId, String expenseId, String userId) async {
    final expDoc = _expenses(groupId).doc(expenseId);
    final run = await decideAndWrite<String?>(_db, [expDoc], (docs, w) {
      final snap = docs[0];
      if (!snap.exists) return 'This expense no longer exists.';
      final expense = ExpenseModel.fromDoc(snap, groupId: groupId);
      if (!expense.isPending) return 'This expense has already been finalised.';
      if (!expense.approvals.containsKey(userId)) return 'That member isn\'t part of this split.';
      w.update(expDoc, {
        'approvals.$userId':        AppConstants.statusPending,
        'rejectionReasons.$userId': FieldValue.delete(),
        // Names who is being asked again; the rules use it to check the
        // logger only reset that one member.
        'requestedAgainFor':        userId,
      });
      return null;
    });
    if (run.result != null) throw AppException(run.result!);
    return run.queued;
  }

  // ── Edit Split Amount + Request Again (custom split only) ───────────────
  /// Sets the target member's share to [newAmount]. The difference is absorbed
  /// by the logger's own share, so the shares always add up to the expense
  /// total. If the logger had left themselves out of the split and the share
  /// goes down, the logger is added with the difference.
  /// Returns true if it was queued offline rather than confirmed.
  Future<bool> editAndRequestAgain(
    String groupId,
    String expenseId,
    String targetUserId,
    double newAmount,
  ) async {
    final expDoc = _expenses(groupId).doc(expenseId);
    final run = await decideAndWrite<String?>(_db, [expDoc], (docs, w) {
      final snap = docs[0];
      if (!snap.exists) return 'This expense no longer exists.';
      final expense = ExpenseModel.fromDoc(snap, groupId: groupId);
      if (!expense.isPending) return 'This expense has already been finalised.';

      final target = expense.splits[targetUserId];
      if (target == null || !expense.approvals.containsKey(targetUserId)) {
        return 'That member isn\'t part of this split.';
      }

      final newCents       = Money.toCents(newAmount);
      final oldCents       = Money.toCents(target.amount);
      final logger         = expense.splits[expense.loggedBy];
      final loggerCents    = logger == null ? 0 : Money.toCents(logger.amount);
      final newLoggerCents = loggerCents - (newCents - oldCents);

      if (newCents <= 0) return 'Enter an amount greater than zero.';
      if (newLoggerCents < 0) {
        return 'That would make the shares add up to more than the expense total. '
            'The most you can ask for is ${Money.format(oldCents + loggerCents)}.';
      }

      final newSplits = Map<String, SplitEntry>.from(expense.splits);
      newSplits[targetUserId] = SplitEntry(userId: targetUserId, name: target.name, amount: Money.fromCents(newCents));
      final addLogger = logger == null && newLoggerCents > 0;
      if (logger != null || addLogger) {
        newSplits[expense.loggedBy] = SplitEntry(
          userId: expense.loggedBy,
          name:   logger?.name ?? expense.loggedByName,
          amount: Money.fromCents(newLoggerCents),
        );
      }

      w.update(expDoc, {
        'splits':                         newSplits.map((k, v) => MapEntry(k, v.toMap())),
        if (addLogger) 'loggerIncluded':  true,
        'approvals.$targetUserId':        AppConstants.statusPending,
        'rejectionReasons.$targetUserId': FieldValue.delete(),
        'requestedAgainFor':              targetUserId,
      });
      return null;
    });
    if (run.result != null) throw AppException(run.result!);
    return run.queued;
  }

  // ── Delete Expense (also removes associated debts) ────────────────────
  /// Refuses to delete an expense once money has moved against it: if any of
  /// its debts has been partly paid, or a payment is waiting for confirmation,
  /// deleting would leave those payments pointing at nothing.
  ///
  /// Needs a connection: the check has to see the server's latest payments,
  /// not whatever happens to be cached on this phone.
  Future<void> deleteExpense(String groupId, String expenseId) async {
    const fromServer = GetOptions(source: Source.server);
    final debtsQuery = await _debts(groupId)
        .where('sourceExpenseId', isEqualTo: expenseId)
        .get(fromServer);

    for (final doc in debtsQuery.docs) {
      final debt = DebtModel.fromDoc(doc, groupId: groupId);
      if (debt.remainingCents < Money.toCents(debt.originalAmount)) {
        throw const AppException(
          'This expense can\'t be deleted because payments have already been confirmed against it.',
        );
      }
    }

    final debtIds = debtsQuery.docs.map((d) => d.id).toList();
    for (var i = 0; i < debtIds.length; i += 10) {
      final chunk    = debtIds.sublist(i, math.min(i + 10, debtIds.length));
      final payments = await _payments(groupId).where('debtId', whereIn: chunk).get(fromServer);
      final hasLivePayment = payments.docs.any((p) {
        final data = p.data() as Map<String, dynamic>? ?? {};
        return data['status'] != AppConstants.statusRejected;
      });
      if (hasLivePayment) {
        throw const AppException(
          'Someone has logged a payment for this expense. Confirm or reject it before deleting.',
        );
      }
    }

    final batch = _db.batch();
    batch.delete(_expenses(groupId).doc(expenseId));
    for (final doc in debtsQuery.docs) {
      batch.delete(doc.reference);
    }
    await saveOrQueue(batch.commit(), 'delete expense');
  }

  /// All approved expenses of a tour, newest first (one-off read, for past tours).
  Future<List<ExpenseModel>> fetchApprovedExpenses(String groupId) async {
    final snap = await _expenses(groupId)
        .where('status', isEqualTo: AppConstants.statusApproved)
        .get();
    return snap.docs.map((d) => ExpenseModel.fromDoc(d, groupId: groupId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

/// Lets [_writeDebts] write into a plain transaction.
class _TxWriterProxy implements ActionWriter {
  _TxWriterProxy(this.tx);
  final Transaction tx;
  @override
  void set(DocumentReference ref, Map<String, dynamic> data) => tx.set(ref, data);
  @override
  void update(DocumentReference ref, Map<String, dynamic> data) => tx.update(ref, data);
}
