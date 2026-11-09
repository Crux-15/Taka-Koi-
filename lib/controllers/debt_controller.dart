import 'dart:async';
import 'package:flutter/material.dart';
import '../models/debt_model.dart';
import '../models/payment_model.dart';
import '../services/debt_service.dart';
import '../services/notification_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_exception.dart';
import '../utils/app_log.dart';
import '../utils/offline.dart';
import '../utils/money.dart';

/// Controller for debt tracking and payment settlement.
class DebtController extends ChangeNotifier {
  /// Services can be swapped for fakes in tests.
  DebtController({DebtService? debtService, NotificationService? notificationService})
      : _debtService  = debtService ?? DebtService(),
        _notifService = notificationService ?? NotificationService();

  final DebtService         _debtService;
  final NotificationService _notifService;

  List<DebtModel>    _iOwe          = [];
  List<DebtModel>    _owedToMe      = [];
  List<PaymentModel> _pendingForMe  = [];
  List<PaymentModel> _myPayments    = []; // payments I logged (any status)
  Map<String, double> _netDebts     = {}; // userId → net amount
  String? _lastError;
  bool    _savedOffline = false;
  bool    _gotIOwe      = false;
  bool    _gotOwedToMe  = false;

  final List<StreamSubscription<dynamic>> _subs = [];
  String? _listeningKey;

  List<DebtModel>    get iOwe         => _iOwe;
  List<DebtModel>    get owedToMe     => _owedToMe;
  List<PaymentModel> get pendingForMe => _pendingForMe;
  Map<String, double> get netDebts    => _netDebts;

  /// False until both debt lists have arrived once, so screens can show a
  /// placeholder instead of a misleading "all settled".
  bool get isLoaded => _gotIOwe && _gotOwedToMe;

  int get iOweCents     => _iOwe.fold(0, (s, d) => s + d.remainingCents);
  int get owedToMeCents => _owedToMe.fold(0, (s, d) => s + d.remainingCents);

  /// Message from the last failed action, safe to show to the user.
  String? get lastError => _lastError;

  /// True if the last payment logged hasn't reached the server yet (no
  /// connection). It's saved on the phone and syncs automatically.
  bool get savedOffline => _savedOffline;

  // ── Streams ───────────────────────────────────────────────────────────────
  /// Starts listening to this user's debts and payments in [groupId].
  /// Calling it again for the same group and user is a no-op; switching to
  /// another group or user stops the old listeners first.
  void listenToDebts(String groupId, String userId) {
    final key = '$groupId/$userId';
    if (_listeningKey == key && _subs.isNotEmpty) return;

    _cancelSubscriptions();
    _listeningKey = key;
    _iOwe = [];
    _owedToMe = [];
    _pendingForMe = [];
    _myPayments = [];
    _netDebts = {};
    _gotIOwe = false;
    _gotOwedToMe = false;

    // On an error (e.g. permission denied after leaving the tour) stop
    // listening; the group controller moves the user out.
    void onError(Object e, StackTrace s) {
      logError('debts stream', e, s);
      _cancelSubscriptions();
      _gotIOwe = _gotOwedToMe = true;
      notifyListeners();
    }

    _subs.add(_debtService.iOweStream(groupId, userId).listen((debts) {
      _iOwe = debts;
      _gotIOwe = true;
      _recomputeNet();
      notifyListeners();
    }, onError: onError));
    _subs.add(_debtService.owedToMeStream(groupId, userId).listen((debts) {
      _owedToMe = debts;
      _gotOwedToMe = true;
      _recomputeNet();
      notifyListeners();
    }, onError: onError));
    _subs.add(_debtService.pendingPaymentsForMeStream(groupId, userId).listen((payments) {
      _pendingForMe = payments;
      notifyListeners();
    }, onError: onError));
    _subs.add(_debtService.myPaymentsStream(groupId, userId).listen((payments) {
      _myPayments = payments;
      notifyListeners();
    }, onError: onError));
  }

  void _cancelSubscriptions() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _listeningKey = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  void _recomputeNet() {
    _netDebts = computeNetDebts(iOwe: _iOwe, owedToMe: _owedToMe);
  }

  // ── Available amounts ─────────────────────────────────────────────────────
  /// Cents I've already logged against [debtId] that are still waiting for
  /// the receiver to confirm.
  int pendingCentsFor(String debtId) => _myPayments
      .where((p) => p.debtId == debtId && p.isPending)
      .fold<int>(0, (sum, p) => sum + Money.toCents(p.amount));

  /// How much I can still log against [debt]: what's owed minus payments
  /// already waiting for confirmation. Never negative.
  int availableCentsFor(DebtModel debt) {
    final available = debt.remainingCents - pendingCentsFor(debt.debtId);
    return available < 0 ? 0 : available;
  }

  /// The debt with [debtId] that I still owe on, or null if it's settled or gone.
  DebtModel? openDebtById(String debtId) =>
      _iOwe.where((d) => d.debtId == debtId && d.isOpen).firstOrNull;

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
    _lastError    = null;
    _savedOffline = false;

    final debt = openDebtById(debtId);
    if (debt == null) {
      _lastError = 'This debt is already settled or no longer exists.';
      return false;
    }
    final cents     = Money.toCents(amount);
    final available = availableCentsFor(debt);
    if (cents <= 0) {
      _lastError = 'Enter an amount greater than zero.';
      return false;
    }
    if (cents > available) {
      _lastError = 'You can log at most $currencySymbol${Money.format(available)} '
          'right now (what\'s owed minus payments waiting for confirmation).';
      return false;
    }

    final String payId;
    try {
      final payment = PaymentModel(
        paymentId:    '',
        groupId:      groupId,
        fromUserId:   fromUserId,
        fromUserName: fromUserName,
        toUserId:     toUserId,
        toUserName:   toUserName,
        debtId:       debtId,
        amount:       Money.fromCents(cents),
        bkashNumber:  bkashNumber,
        status:       AppConstants.statusPending,
        loggedAt:     DateTime.now(),
      );
      final saved = await _debtService.logPayment(groupId, payment);
      payId         = saved.id;
      _savedOffline = !saved.synced;
    } catch (e) {
      _lastError = friendlyError(e, 'Failed to log payment.');
      return false;
    }

    // The payment is saved; a failed notification shouldn't make the payer
    // think it wasn't, or they may log it a second time.
    inBackground(
      _notifService.send(
        targetUserId: toUserId,
        groupId:      groupId,
        type:         AppConstants.notifPaymentPending,
        referenceId:  payId,
        message:      '$fromUserName has logged a payment of $currencySymbol${Money.format(cents)} to you. Please review.',
      ),
      'notify payment logged',
    );
    notifyListeners();
    return true;
  }

  // ── Approve Payment ───────────────────────────────────────────────────────
  Future<bool> approvePayment(String groupId, PaymentModel payment, String currencySymbol) async {
    _lastError    = null;
    _savedOffline = false;
    final double remaining;
    try {
      final result = await _debtService.approvePayment(groupId, payment.paymentId);
      remaining     = result.remaining;
      _savedOffline = result.queued;
    } catch (e) {
      _lastError = friendlyError(e, 'Failed to approve. Try again.');
      notifyListeners();
      return false;
    }

    final remainingCents = Money.toCents(remaining);
    final outcome = remainingCents == 0
        ? 'Debt settled!'
        : '$currencySymbol${Money.format(remainingCents)} is still owed.';
    inBackground(
      _notifService.send(
        targetUserId: payment.fromUserId,
        groupId:      groupId,
        type:         AppConstants.notifPaymentApproved,
        referenceId:  payment.paymentId,
        message:      '${payment.toUserName} confirmed your payment of '
            '$currencySymbol${Money.format(Money.toCents(payment.amount))}. $outcome',
      ),
      'notify payment approved',
    );
    notifyListeners();
    return true;
  }

  // ── Reject Payment ────────────────────────────────────────────────────────
  Future<bool> rejectPayment(String groupId, PaymentModel payment, String note, String currencySymbol) async {
    _lastError = null;
    try {
      await _debtService.rejectPayment(groupId, payment.paymentId, note);
    } catch (e) {
      _lastError = friendlyError(e, 'Failed to reject. Try again.');
      notifyListeners();
      return false;
    }
    inBackground(
      _notifService.send(
        targetUserId: payment.fromUserId,
        groupId:      groupId,
        type:         AppConstants.notifPaymentRejected,
        referenceId:  payment.paymentId,
        message:      '${payment.toUserName} rejected your payment of ${Money.display(payment.amount, currencySymbol)}${note.isNotEmpty ? ': "$note"' : ''}. You can log it again with the right amount.',
      ),
      'notify payment rejected',
    );
    notifyListeners();
    return true;
  }
}
