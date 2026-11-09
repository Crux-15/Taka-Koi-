import 'dart:async';
import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../services/expense_service.dart';
import '../services/geo_service.dart';
import '../services/notification_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_exception.dart';
import '../utils/app_log.dart';
import '../utils/offline.dart';
import '../utils/money.dart';

enum ExpenseStatus { initial, loading, loaded, error }

/// Controller for expense logging, approval, and history.
class ExpenseController extends ChangeNotifier {
  /// Services can be swapped for fakes in tests.
  ExpenseController({
    ExpenseService?      expenseService,
    GeoService?          geoService,
    NotificationService? notificationService,
  })  : _expenseService = expenseService ?? ExpenseService(),
        _geoService     = geoService ?? GeoService(),
        _notifService   = notificationService ?? NotificationService();

  final ExpenseService      _expenseService;
  final GeoService          _geoService;
  final NotificationService _notifService;

  ExpenseStatus       _status        = ExpenseStatus.initial;
  String?             _errorMessage;
  List<ExpenseModel>  _approvedList  = [];
  List<ExpenseModel>  _myExpenses    = [];
  ExpenseLocation?    _capturedLocation;
  bool                _capturingGps  = false;
  bool                _savedOffline  = false;
  bool                _approvedLoaded = false;

  // One live listener of each kind. Opening Home again (or switching tour or
  // account) replaces it instead of adding another on top.
  StreamSubscription<List<ExpenseModel>>? _approvedSub;
  StreamSubscription<List<ExpenseModel>>? _mySub;
  String? _approvedKey;
  String? _myKey;

  ExpenseStatus      get status           => _status;
  String?            get errorMessage     => _errorMessage;
  List<ExpenseModel> get myExpenses       => _myExpenses;
  ExpenseLocation?   get capturedLocation => _capturedLocation;
  bool               get capturingGps     => _capturingGps;
  bool               get isLoading        => _status == ExpenseStatus.loading;

  /// Approved expenses of the tour, newest first.
  List<ExpenseModel> get approvedExpenses => _approvedList;

  /// False until the tour's approved expenses have arrived once.
  bool               get approvedLoaded   => _approvedLoaded;

  /// True if the last expense logged hasn't reached the server yet (no
  /// connection). It's saved on the phone and syncs automatically.
  bool               get savedOffline     => _savedOffline;

  // ── Streams ───────────────────────────────────────────────────────────────
  void listenToApprovedExpenses(String groupId) {
    if (_approvedKey == groupId && _approvedSub != null) return;
    _approvedSub?.cancel();
    _approvedKey  = groupId;
    _approvedList = [];
    _approvedLoaded = false;
    _approvedSub  = _expenseService.approvedExpensesStream(groupId).listen((list) {
      _approvedList = list;
      _approvedLoaded = true;
      notifyListeners();
    }, onError: (Object e, StackTrace s) {
      // e.g. permission denied after leaving the tour; the group controller
      // handles moving the user out, so just stop listening.
      logError('approved expenses stream', e, s);
      _approvedLoaded = true;
      _approvedSub = null;
      _approvedKey = null;
    });
  }

  void listenToMyExpenses(String groupId, String userId) {
    final key = '$groupId/$userId';
    if (_myKey == key && _mySub != null) return;
    _mySub?.cancel();
    _myKey      = key;
    _myExpenses = [];
    _mySub      = _expenseService.myExpensesStream(groupId, userId).listen((list) {
      _myExpenses = list;
      _finishFullyApproved(groupId, userId, list);
      notifyListeners();
    }, onError: (Object e, StackTrace s) {
      logError('my expenses stream', e, s);
      _mySub = null;
      _myKey = null;
    });
  }

  final Set<String> _finishing = {};

  /// Everyone approved (some of them offline) but nobody's approval was the
  /// "last" one, so the expense is still pending. The logger's app finishes
  /// it: marks it approved and creates the debts, exactly once.
  void _finishFullyApproved(String groupId, String userId, List<ExpenseModel> mine) {
    for (final e in mine) {
      final stuck = e.isPending
          && e.loggedBy == userId
          && e.approvals.isNotEmpty
          && e.approvals.values.every((v) => v == AppConstants.statusApproved);
      if (!stuck || !_finishing.add(e.expenseId)) continue;
      _expenseService
          .finaliseIfAllApproved(groupId, e.expenseId)
          .catchError((Object err, StackTrace s) {
            logError('finish fully approved expense', err, s);
            return false;
          })
          .whenComplete(() => _finishing.remove(e.expenseId));
    }
  }

  @override
  void dispose() {
    _approvedSub?.cancel();
    _mySub?.cancel();
    super.dispose();
  }

  /// Real-time stream for a single expense document — used by ExpenseDetailView.
  Stream<ExpenseModel> expenseStream(String groupId, String expenseId) =>
      _expenseService.expenseStream(groupId, expenseId);

  // ── GPS Capture ───────────────────────────────────────────────────────────
  Future<void> captureGps() async {
    _capturingGps = true;
    notifyListeners();
    _capturedLocation = await _geoService.captureLocation();
    _capturingGps = false;
    notifyListeners();
  }

  // ── Log Expense ───────────────────────────────────────────────────────────
  /// Solo expenses (no other split members) are auto-approved immediately.
  /// Split expenses go to 'pending' and approval requests are sent to each member.
  Future<bool> logExpense({
    required String groupId,
    required String loggedBy,
    required String loggedByName,
    required double amount,
    required String comment,
    required String splitType,
    required Map<String, SplitEntry> splits,
    required bool loggerIncluded,
    required GroupModel group,
  }) async {
    _setLoading();
    _savedOffline = false;
    final String expId;
    try {
      final expense = ExpenseModel(
        expenseId:      '',
        groupId:        groupId,
        loggedBy:       loggedBy,
        loggedByName:   loggedByName,
        amount:         amount,
        comment:        comment,
        location:       _capturedLocation,
        splitType:      splitType,
        splits:         splits,
        loggerIncluded: loggerIncluded,
        status:         AppConstants.statusPending, // service decides final status
        createdAt:      DateTime.now(),
      );

      final saved = await _expenseService.logExpense(groupId, expense);
      expId         = saved.id;
      _savedOffline = !saved.synced;
    } catch (e) {
      _setError(friendlyError(e, 'Failed to log expense. Please try again.'));
      return false;
    }

    // The expense is saved. A failed notification must not be reported as a
    // failed expense, or the logger may submit it again and double-count it.
    final approvalMembers = splits.keys.where((uid) => uid != loggedBy).toList();
    for (final uid in approvalMembers) {
      inBackground(
        _notifService.send(
          targetUserId: uid,
          groupId:      groupId,
          type:         AppConstants.notifExpensePendingApproval,
          referenceId:  expId,
          message:      '$loggedByName wants to split an expense of '
              '${Money.display(splits[uid]!.amount, group.currencySymbol)} with you. Tap to approve or reject.',
        ),
        'notify split member',
      );
    }

    _clearLocation();
    _status = ExpenseStatus.loaded;
    notifyListeners();
    return true;
  }

  // ── Approve Expense ───────────────────────────────────────────────────────
  /// Called by a split member to approve.
  /// If all members approve, notifies the logger and creates debts.
  Future<bool> approveExpense({
    required String groupId,
    required String expenseId,
    required String approverId,
    required String approverName,
    required String loggedBy,
    required String expenseTitle,
    required String currencySymbol,
    required double totalAmount,
  }) async {
    _setLoading();
    _savedOffline = false;
    final bool allApproved;
    try {
      final result = await _expenseService.approveExpense(
        groupId, expenseId, approverId,
      );
      allApproved   = result.finalised;
      _savedOffline = result.queued;
    } catch (e) {
      _setError(friendlyError(e, 'Failed to approve expense.'));
      return false;
    }

    if (allApproved) {
      // Notify the expense logger that everyone approved. The approval is
      // already saved, so a failed notification isn't reported as a failure.
      inBackground(
        _notifService.send(
          targetUserId: loggedBy,
          groupId:      groupId,
          type:         AppConstants.notifExpenseApproved,
          referenceId:  expenseId,
          message:      'Your expense of ${Money.display(totalAmount, currencySymbol)} '
              'has been fully approved by all members!',
        ),
        'notify expense approved',
      );
    }

    _status = ExpenseStatus.loaded;
    notifyListeners();
    return true;
  }

  // ── Reject Expense ────────────────────────────────────────────────────────
  /// Called by a split member to reject, with an optional reason.
  /// Notifies the expense logger.
  Future<bool> rejectExpense({
    required String groupId,
    required String expenseId,
    required String rejecterId,
    required String rejecterName,
    required String loggedBy,
    required String currencySymbol,
    required double totalAmount,
    String reason = '',
  }) async {
    _setLoading();
    try {
      _savedOffline = await _expenseService.rejectExpense(groupId, expenseId, rejecterId, reason);
    } catch (e) {
      _setError(friendlyError(e, 'Failed to reject expense.'));
      return false;
    }

    // Notify the expense logger of the rejection. The rejection is already
    // saved, so a failed notification isn't reported as a failure.
    final reasonText = reason.trim().isNotEmpty ? ' Reason: "$reason"' : '';
    inBackground(
      _notifService.send(
        targetUserId: loggedBy,
        groupId:      groupId,
        type:         AppConstants.notifExpenseRejected,
        referenceId:  expenseId,
        message:      '$rejecterName rejected your expense of '
            '${Money.display(totalAmount, currencySymbol)}.$reasonText Tap to view details.',
      ),
      'notify expense rejected',
    );

    _status = ExpenseStatus.loaded;
    notifyListeners();
    return true;
  }

  // ── Request Again ─────────────────────────────────────────────────────────
  /// Logger re-requests approval from a rejected member.
  Future<bool> requestAgain({
    required String groupId,
    required String expenseId,
    required String targetUserId,
    required String loggedByName,
    required String currencySymbol,
    required double memberAmount,
  }) async {
    _setLoading();
    try {
      _savedOffline = await _expenseService.requestAgain(groupId, expenseId, targetUserId);
    } catch (e) {
      _setError(friendlyError(e, 'Failed to send request.'));
      return false;
    }

    // Re-send the approval notification
    inBackground(
      _notifService.send(
        targetUserId: targetUserId,
        groupId:      groupId,
        type:         AppConstants.notifExpensePendingApproval,
        referenceId:  expenseId,
        message:      '$loggedByName is requesting your approval again for '
            '${Money.display(memberAmount, currencySymbol)}. Tap to approve or reject.',
      ),
      'notify request again',
    );

    _status = ExpenseStatus.loaded;
    notifyListeners();
    return true;
  }

  // ── Edit Amount + Request Again ───────────────────────────────────────────
  /// Logger edits the target member's amount (custom split only) and re-requests.
  Future<bool> editAndRequestAgain({
    required String groupId,
    required String expenseId,
    required String targetUserId,
    required double newAmount,
    required String loggedByName,
    required String currencySymbol,
  }) async {
    _setLoading();
    try {
      _savedOffline = await _expenseService.editAndRequestAgain(
        groupId, expenseId, targetUserId, newAmount,
      );
    } catch (e) {
      _setError(friendlyError(e, 'Failed to update and re-request.'));
      return false;
    }

    // Re-send the approval notification with updated amount
    inBackground(
      _notifService.send(
        targetUserId: targetUserId,
        groupId:      groupId,
        type:         AppConstants.notifExpensePendingApproval,
        referenceId:  expenseId,
        message:      '$loggedByName updated your share to '
            '${Money.display(newAmount, currencySymbol)} and is requesting your approval again.',
      ),
      'notify share edited',
    );

    _status = ExpenseStatus.loaded;
    notifyListeners();
    return true;
  }

  // ── Delete Expense ────────────────────────────────────────────────────────
  /// Admin direct-delete (no approval needed).
  /// On failure, [errorMessage] says why (e.g. payments already recorded).
  Future<bool> deleteExpense(String groupId, String expenseId) async {
    try {
      await _expenseService.deleteExpense(groupId, expenseId);
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e, 'Failed to delete expense.');
      return false;
    }
  }

  /// Member requests deletion — sends a notification to the admin for approval.
  Future<bool> requestDeleteExpense({
    required String groupId,
    required String groupName,
    required String expenseId,
    required String adminId,
    required String memberName,
    required String currencySymbol,
    required double amount,
  }) async {
    try {
      await _notifService.send(
        targetUserId: adminId,
        groupId:      groupId,
        groupName:    groupName,
        type:         AppConstants.notifDeleteExpenseRequest,
        referenceId:  expenseId,
        message:      '$memberName is requesting to delete an expense of '
            '${Money.display(amount, currencySymbol)}. Tap to review.',
      );
      return true;
    } catch (e, s) {
      logError('request delete expense', e, s);
      _errorMessage = friendlyError(e, 'Failed to send the request. Try again.');
      return false;
    }
  }

  /// Admin approves deletion — deletes the expense and notifies the member.
  Future<bool> approveDeleteExpense({
    required String groupId,
    required String groupName,
    required String expenseId,
    required String memberId,
    required String memberName,
    required String currencySymbol,
    required double amount,
  }) async {
    try {
      await _expenseService.deleteExpense(groupId, expenseId);
    } catch (e) {
      _errorMessage = friendlyError(e, 'Failed to delete expense. Try again.');
      return false;
    }
    inBackground(
      _notifService.send(
        targetUserId: memberId,
        groupId:      groupId,
        groupName:    groupName,
        type:         AppConstants.notifDeleteExpenseApproved,
        referenceId:  expenseId,
        message:      'Your expense of ${Money.display(amount, currencySymbol)} '
            'has been deleted as per your request.',
      ),
      'notify delete approved',
    );
    return true;
  }

  /// Admin rejects deletion — notifies the member (expense stays).
  Future<bool> rejectDeleteExpense({
    required String groupId,
    required String groupName,
    required String expenseId,
    required String memberId,
    required String memberName,
    required String currencySymbol,
    required double amount,
  }) async {
    try {
      await _notifService.send(
        targetUserId: memberId,
        groupId:      groupId,
        groupName:    groupName,
        type:         AppConstants.notifDeleteExpenseRejected,
        referenceId:  expenseId,
        message:      'Your delete request for the expense of '
            '${Money.display(amount, currencySymbol)} was rejected by the admin. '
            'Tap to re-request.',
      );
      return true;
    } catch (e, s) {
      logError('reject delete expense', e, s);
      _errorMessage = friendlyError(e, 'Failed to send. Try again.');
      return false;
    }
  }

  // ── Computed: Member Totals for Home Dashboard ────────────────────────────
  Map<String, double> computeMemberTotals() {
    final totals = <String, double>{};
    for (final e in _approvedList) {
      totals[e.loggedBy] = (totals[e.loggedBy] ?? 0) + e.amount;
    }
    return totals;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setLoading() {
    _status       = ExpenseStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status       = ExpenseStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearLocation() => _capturedLocation = null;

  void clearError() {
    _errorMessage = null;
    _status       = ExpenseStatus.loaded;
    notifyListeners();
  }
}
