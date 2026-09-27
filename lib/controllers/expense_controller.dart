import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../services/expense_service.dart';
import '../services/geo_service.dart';
import '../services/notification_service.dart';
import '../utils/app_constants.dart';

enum ExpenseStatus { initial, loading, loaded, error }

/// Controller for expense logging, approval, and history.
class ExpenseController extends ChangeNotifier {
  final ExpenseService      _expenseService = ExpenseService();
  final GeoService          _geoService     = GeoService();
  final NotificationService _notifService   = NotificationService();

  ExpenseStatus       _status        = ExpenseStatus.initial;
  String?             _errorMessage;
  List<ExpenseModel>  _approvedList  = [];
  List<ExpenseModel>  _myExpenses    = [];
  ExpenseLocation?    _capturedLocation;
  bool                _capturingGps  = false;

  ExpenseStatus      get status           => _status;
  String?            get errorMessage     => _errorMessage;
  List<ExpenseModel> get approvedList     => _approvedList;
  List<ExpenseModel> get myExpenses       => _myExpenses;
  ExpenseLocation?   get capturedLocation => _capturedLocation;
  bool               get capturingGps     => _capturingGps;
  bool               get isLoading        => _status == ExpenseStatus.loading;

  // ── Streams ───────────────────────────────────────────────────────────────
  void listenToApprovedExpenses(String groupId) {
    _expenseService.approvedExpensesStream(groupId).listen((list) {
      _approvedList = list;
      notifyListeners();
    });
  }

  void listenToMyExpenses(String groupId, String userId) {
    _expenseService.myExpensesStream(groupId, userId).listen((list) {
      _myExpenses = list;
      notifyListeners();
    });
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

  void clearLocation() {
    _capturedLocation = null;
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

      final expId = await _expenseService.logExpense(groupId, expense);

      // Non-logger split members who need to approve
      final approvalMembers = splits.keys.where((uid) => uid != loggedBy).toList();

      if (approvalMembers.isEmpty) {
        // Solo expense — just notify (no approval needed)
        // (nothing extra to do)
      } else {
        // Send approval-request notification to each split member
        for (final uid in approvalMembers) {
          await _notifService.send(
            targetUserId: uid,
            groupId:      groupId,
            type:         AppConstants.notifExpensePendingApproval,
            referenceId:  expId,
            message:      '$loggedByName wants to split an expense of '
                '${group.currencySymbol}${splits[uid]!.amount.toStringAsFixed(2)} with you. Tap to approve or reject.',
          );
        }
      }

      _clearLocation();
      _status = ExpenseStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to log expense. Please try again.');
      return false;
    }
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
    try {
      final allApproved = await _expenseService.approveExpense(
        groupId, expenseId, approverId,
      );

      if (allApproved) {
        // Notify the expense logger that everyone approved
        await _notifService.send(
          targetUserId: loggedBy,
          groupId:      groupId,
          type:         AppConstants.notifExpenseApproved,
          referenceId:  expenseId,
          message:      'Your expense of $currencySymbol${totalAmount.toStringAsFixed(2)} '
              'has been fully approved by all members!',
        );
      }

      _status = ExpenseStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to approve expense.');
      return false;
    }
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
      await _expenseService.rejectExpense(groupId, expenseId, rejecterId, reason);

      // Notify the expense logger of the rejection
      final reasonText = reason.trim().isNotEmpty ? ' Reason: "$reason"' : '';
      await _notifService.send(
        targetUserId: loggedBy,
        groupId:      groupId,
        type:         AppConstants.notifExpenseRejected,
        referenceId:  expenseId,
        message:      '$rejecterName rejected your expense of '
            '$currencySymbol${totalAmount.toStringAsFixed(2)}.$reasonText Tap to view details.',
      );

      _status = ExpenseStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to reject expense.');
      return false;
    }
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
      await _expenseService.requestAgain(groupId, expenseId, targetUserId);

      // Re-send the approval notification
      await _notifService.send(
        targetUserId: targetUserId,
        groupId:      groupId,
        type:         AppConstants.notifExpensePendingApproval,
        referenceId:  expenseId,
        message:      '$loggedByName is requesting your approval again for '
            '$currencySymbol${memberAmount.toStringAsFixed(2)}. Tap to approve or reject.',
      );

      _status = ExpenseStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to send request.');
      return false;
    }
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
      await _expenseService.editAndRequestAgain(
        groupId, expenseId, targetUserId, newAmount,
      );

      // Re-send the approval notification with updated amount
      await _notifService.send(
        targetUserId: targetUserId,
        groupId:      groupId,
        type:         AppConstants.notifExpensePendingApproval,
        referenceId:  expenseId,
        message:      '$loggedByName updated your share to '
            '$currencySymbol${newAmount.toStringAsFixed(2)} and is requesting your approval again.',
      );

      _status = ExpenseStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update and re-request.');
      return false;
    }
  }

  // ── Delete Expense ────────────────────────────────────────────────────────
  /// Admin direct-delete (no approval needed).
  Future<bool> deleteExpense(String groupId, String expenseId) async {
    try {
      await _expenseService.deleteExpense(groupId, expenseId);
      return true;
    } catch (_) {
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
            '$currencySymbol${amount.toStringAsFixed(2)}. Tap to review.',
      );
      return true;
    } catch (_) {
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
      await _notifService.send(
        targetUserId: memberId,
        groupId:      groupId,
        groupName:    groupName,
        type:         AppConstants.notifDeleteExpenseApproved,
        referenceId:  expenseId,
        message:      'Your expense of $currencySymbol${amount.toStringAsFixed(2)} '
            'has been deleted as per your request.',
      );
      return true;
    } catch (_) {
      return false;
    }
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
            '$currencySymbol${amount.toStringAsFixed(2)} was rejected by the admin. '
            'Tap to re-request.',
      );
      return true;
    } catch (_) {
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
