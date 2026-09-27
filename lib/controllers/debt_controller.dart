import 'package:flutter/material.dart';
import '../models/debt_model.dart';
import '../models/payment_model.dart';
import '../services/debt_service.dart';
import '../services/notification_service.dart';
import '../utils/app_constants.dart';

/// Controller for debt tracking and payment settlement.
class DebtController extends ChangeNotifier {
  final DebtService         _debtService  = DebtService();
  final NotificationService _notifService = NotificationService();

  List<DebtModel>   _iOwe           = [];
  List<DebtModel>   _owedToMe       = [];
  List<PaymentModel> _pendingForMe  = [];
  Map<String, double> _netDebts     = {}; // userId → net amount

  List<DebtModel>    get iOwe         => _iOwe;
  List<DebtModel>    get owedToMe     => _owedToMe;
  List<PaymentModel> get pendingForMe => _pendingForMe;
  Map<String, double> get netDebts    => _netDebts;

  // ── Streams ───────────────────────────────────────────────────────────────
  void listenToDebts(String groupId, String userId) {
    _debtService.iOweStream(groupId, userId).listen((debts) {
      _iOwe = debts;
      _recomputeNet();
      notifyListeners();
    });
    _debtService.owedToMeStream(groupId, userId).listen((debts) {
      _owedToMe = debts;
      _recomputeNet();
      notifyListeners();
    });
    _debtService.pendingPaymentsForMeStream(groupId, userId).listen((payments) {
      _pendingForMe = payments;
      notifyListeners();
    });
  }

  void _recomputeNet() {
    _netDebts = computeNetDebts(iOwe: _iOwe, owedToMe: _owedToMe);
  }

  // ── Log Payment ───────────────────────────────────────────────────────────
  Future<bool> logPayment({
    required String groupId,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required String toUserName,
    required String debtId,
    required double amount,
    required String currencySymbol,
    String? bkashNumber,
  }) async {
    try {
      final payment = PaymentModel(
        paymentId:    '',
        groupId:      groupId,
        fromUserId:   fromUserId,
        fromUserName: fromUserName,
        toUserId:     toUserId,
        toUserName:   toUserName,
        debtId:       debtId,
        amount:       amount,
        bkashNumber:  bkashNumber,
        status:       AppConstants.statusPending,
        loggedAt:     DateTime.now(),
      );
      final payId = await _debtService.logPayment(groupId, payment);
      // Notify receiver to review payment — use correct currency symbol
      await _notifService.send(
        targetUserId: toUserId,
        groupId:      groupId,
        type:         AppConstants.notifPaymentApproved, // reused as "payment logged" trigger
        referenceId:  payId,
        message:      '$fromUserName has logged a payment of $currencySymbol${amount.toStringAsFixed(2)} to you. Please review.',
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Approve Payment ───────────────────────────────────────────────────────
  Future<bool> approvePayment(String groupId, PaymentModel payment, String currencySymbol) async {
    try {
      await _debtService.approvePayment(groupId, payment);
      await _notifService.send(
        targetUserId: payment.fromUserId,
        groupId:      groupId,
        type:         AppConstants.notifPaymentApproved,
        referenceId:  payment.paymentId,
        message:      '${payment.toUserName} confirmed your payment of $currencySymbol${payment.amount.toStringAsFixed(2)}. Debt settled!',
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Reject Payment ────────────────────────────────────────────────────────
  Future<bool> rejectPayment(String groupId, PaymentModel payment, String note, String currencySymbol) async {
    try {
      await _debtService.rejectPayment(groupId, payment.paymentId, note);
      await _notifService.send(
        targetUserId: payment.fromUserId,
        groupId:      groupId,
        type:         AppConstants.notifPaymentRejected,
        referenceId:  payment.paymentId,
        message:      '${payment.toUserName} rejected your payment of $currencySymbol${payment.amount.toStringAsFixed(2)}${note.isNotEmpty ? ': "$note"' : ''}. You can edit and resubmit.',
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Resubmit Payment ──────────────────────────────────────────────────────
  Future<bool> resubmitPayment(
    String groupId,
    String paymentId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _debtService.resubmitPayment(groupId, paymentId, updates);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Bkash Request ─────────────────────────────────────────────────────────
  Future<void> requestBkash({
    required String groupId,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required String? toUserBkash,
  }) async {
    if (toUserBkash != null && toUserBkash.isNotEmpty) {
      // Receiver has Bkash → send request notification
      await _notifService.send(
        targetUserId: toUserId,
        groupId:      groupId,
        type:         AppConstants.notifBkashRequested,
        referenceId:  fromUserId,
        message:      '$fromUserName is requesting your Bkash number to make a payment.',
      );
    } else {
      // Receiver has no Bkash → notify them to add
      await _notifService.send(
        targetUserId: toUserId,
        groupId:      groupId,
        type:         AppConstants.notifBkashAddRequired,
        referenceId:  fromUserId,
        message:      '$fromUserName wants to pay you via Bkash. Please add your Bkash number in your profile.',
      );
      // Also inform the requester
      await _notifService.send(
        targetUserId: fromUserId,
        groupId:      groupId,
        type:         AppConstants.notifBkashAddRequired,
        referenceId:  toUserId,
        message:      'The recipient has not added a Bkash number yet. They have been notified.',
      );
    }
  }
}
