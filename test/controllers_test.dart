import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tour_expense_tracker/controllers/debt_controller.dart';
import 'package:tour_expense_tracker/controllers/expense_controller.dart';
import 'package:tour_expense_tracker/models/debt_model.dart';
import 'package:tour_expense_tracker/models/expense_model.dart';
import 'package:tour_expense_tracker/models/group_model.dart';
import 'package:tour_expense_tracker/models/payment_model.dart';
import 'package:tour_expense_tracker/services/debt_service.dart';
import 'package:tour_expense_tracker/services/expense_service.dart';
import 'package:tour_expense_tracker/services/geo_service.dart';
import 'package:tour_expense_tracker/services/notification_service.dart';
import 'package:tour_expense_tracker/utils/app_constants.dart';

// ── Fakes (no Firebase) ──────────────────────────────────────────────────────

class FakeNotifications implements NotificationService {
  final sent = <String>[];
  /// Like sending with no connection: never confirmed.
  bool hang = false;

  @override
  Future<bool> send({
    required String targetUserId,
    required String groupId,
    required String type,
    required String referenceId,
    required String message,
    String groupName = '',
  }) {
    sent.add(targetUserId);
    return hang ? Completer<bool>().future : Future.value(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDebts implements DebtService {
  FakeDebts(this.iOwe, {this.myPayments = const []});
  final List<DebtModel> iOwe;
  final List<PaymentModel> myPayments;
  final logged = <PaymentModel>[];
  bool synced = true;

  @override
  Stream<List<DebtModel>> iOweStream(String groupId, String userId) => Stream.value(iOwe);
  @override
  Stream<List<DebtModel>> owedToMeStream(String groupId, String userId) => Stream.value(const []);
  @override
  Stream<List<PaymentModel>> pendingPaymentsForMeStream(String groupId, String userId) => Stream.value(const []);
  @override
  Stream<List<PaymentModel>> myPaymentsStream(String groupId, String userId) => Stream.value(myPayments);

  @override
  Future<({String id, bool synced})> logPayment(String groupId, PaymentModel payment) async {
    logged.add(payment);
    return (id: 'p${logged.length}', synced: synced);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExpenses implements ExpenseService {
  bool synced = true;
  final logged = <ExpenseModel>[];

  @override
  Future<({String id, bool synced})> logExpense(String groupId, ExpenseModel expense) async {
    logged.add(expense);
    return (id: 'e1', synced: synced);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGeo implements GeoService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

DebtModel _debt(String id, double remaining) => DebtModel(
      debtId:          id,
      groupId:         'g',
      fromUserId:      'me',
      fromUserName:    'Me',
      toUserId:        'bob',
      toUserName:      'Bob',
      sourceExpenseId: 'e',
      originalAmount:  remaining,
      remainingAmount: remaining,
      status:          AppConstants.statusActive,
      createdAt:       DateTime(2026),
    );

PaymentModel _pending(String debtId, double amount) => PaymentModel(
      paymentId:    'old',
      groupId:      'g',
      fromUserId:   'me',
      fromUserName: 'Me',
      toUserId:     'bob',
      toUserName:   'Bob',
      debtId:       debtId,
      amount:       amount,
      status:       AppConstants.statusPending,
      loggedAt:     DateTime(2026),
    );

GroupModel _group() {
  final now = DateTime(2026);
  return GroupModel(
    groupId:            'g',
    name:               'Trip',
    adminId:            'me',
    creatorId:          'me',
    currency:           'BDT',
    currencySymbol:     '৳',
    status:             'active',
    groupCode:          'ABC234',
    groupCodeExpiresAt: now,
    lastActivityAt:     now,
    createdAt:          now,
    members: {
      for (final uid in ['me', 'bob', 'carol'])
        uid: GroupMember(userId: uid, name: uid, avatarUrl: '', joinedAt: now),
    },
  );
}

Future<bool> _pay(DebtController c, String debtId, double amount) => c.logPayment(
      groupId:        'g',
      fromUserId:     'me',
      fromUserName:   'Me',
      toUserId:       'bob',
      toUserName:     'Bob',
      debtId:         debtId,
      amount:         amount,
      currencySymbol: '৳',
    );

void main() {
  group('DebtController.logPayment', () {
    Future<(DebtController, FakeDebts, FakeNotifications)> setUp({
      List<PaymentModel> pending = const [],
    }) async {
      final debts  = FakeDebts([_debt('d1', 100)], myPayments: pending);
      final notifs = FakeNotifications();
      final c = DebtController(debtService: debts, notificationService: notifs)
        ..listenToDebts('g', 'me');
      await Future<void>.delayed(Duration.zero); // let the streams deliver
      return (c, debts, notifs);
    }

    test('logs a payment and tells the receiver', () async {
      final (c, debts, notifs) = await setUp();
      expect(await _pay(c, 'd1', 40), isTrue);
      expect(debts.logged.single.amount, 40);
      expect(notifs.sent, ['bob']);
      expect(c.savedOffline, isFalse);
    });

    test('can\'t pay more than what\'s owed minus payments still waiting', () async {
      final (c, debts, _) = await setUp(pending: [_pending('d1', 70)]);
      expect(await _pay(c, 'd1', 40), isFalse);
      expect(c.lastError, contains('at most ৳30.00'));
      expect(debts.logged, isEmpty);
      expect(await _pay(c, 'd1', 30), isTrue);
    });

    test('an unknown debt is refused instead of falling back to another one', () async {
      final (c, debts, _) = await setUp();
      expect(await _pay(c, 'nope', 10), isFalse);
      expect(debts.logged, isEmpty);
    });

    test('offline: reports it as saved on the phone, without waiting on the notification', () async {
      final (c, debts, notifs) = await setUp();
      debts.synced = false;
      notifs.hang  = true;
      final ok = await _pay(c, 'd1', 10).timeout(const Duration(seconds: 1));
      expect(ok, isTrue);
      expect(c.savedOffline, isTrue);
    });
  });

  group('ExpenseController.logExpense', () {
    Future<bool> log(ExpenseController c) => c.logExpense(
          groupId:        'g',
          loggedBy:       'me',
          loggedByName:   'Me',
          amount:         90,
          comment:        'Dinner',
          splitType:      AppConstants.splitEqual,
          splits: const {
            'me':    SplitEntry(userId: 'me', name: 'Me', amount: 30),
            'bob':   SplitEntry(userId: 'bob', name: 'Bob', amount: 30),
            'carol': SplitEntry(userId: 'carol', name: 'Carol', amount: 30),
          },
          loggerIncluded: true,
          group:          _group(),
        );

    test('asks each other member to approve', () async {
      final notifs = FakeNotifications();
      final c = ExpenseController(
        expenseService:      FakeExpenses(),
        geoService:          FakeGeo(),
        notificationService: notifs,
      );
      expect(await log(c), isTrue);
      expect(notifs.sent, unorderedEquals(['bob', 'carol']));
      expect(c.savedOffline, isFalse);
    });

    test('offline: finishes straight away and says it will sync', () async {
      final expenses = FakeExpenses()..synced = false;
      final notifs   = FakeNotifications()..hang = true;
      final c = ExpenseController(
        expenseService:      expenses,
        geoService:          FakeGeo(),
        notificationService: notifs,
      );
      expect(await log(c).timeout(const Duration(seconds: 1)), isTrue);
      expect(c.savedOffline, isTrue);
      expect(c.isLoading, isFalse);
    });
  });
}
