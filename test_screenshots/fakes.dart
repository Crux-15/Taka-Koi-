// Demo tour and in-memory services for the screenshot tests (no Firebase).

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:tour_expense_tracker/models/bkash_share.dart';
import 'package:tour_expense_tracker/models/debt_model.dart';
import 'package:tour_expense_tracker/models/expense_model.dart';
import 'package:tour_expense_tracker/models/group_model.dart';
import 'package:tour_expense_tracker/models/notification_model.dart';
import 'package:tour_expense_tracker/models/payment_model.dart';
import 'package:tour_expense_tracker/models/user_model.dart';
import 'package:tour_expense_tracker/services/auth_service.dart';
import 'package:tour_expense_tracker/services/bkash_service.dart';
import 'package:tour_expense_tracker/services/debt_service.dart';
import 'package:tour_expense_tracker/services/expense_service.dart';
import 'package:tour_expense_tracker/services/geo_service.dart';
import 'package:tour_expense_tracker/services/group_service.dart';
import 'package:tour_expense_tracker/services/notification_service.dart';

/// The same demo tour as rules_test/seed_emulator.mjs, frozen at a fixed time
/// relative to "now" so screenshots read naturally.
class Demo {
  static final DateTime now = DateTime.now();
  static DateTime ago(Duration d) => now.subtract(d);

  static const names = {
    'nafis':  'Nafis Rahman',
    'tasnim': 'Tasnim Akter',
    'rafi':   'Rafi Hasan',
    'anika':  'Anika Chowdhury',
  };

  static final me = UserModel(
    uid: 'nafis', name: 'Nafis Rahman', email: 'nafis@taka.test', avatarUrl: '',
    bkashNumber: '01811111111', activeGroupId: 'g-coxs', createdAt: ago(const Duration(days: 30)),
  );

  static final group = GroupModel(
    groupId: 'g-coxs', name: 'Cox\'s Bazar Getaway', adminId: 'nafis', creatorId: 'nafis',
    currency: 'BDT', currencySymbol: '৳', status: 'active', groupCode: 'TK7Q2M',
    groupCodeExpiresAt: now.add(const Duration(minutes: 44)),
    lastActivityAt: ago(const Duration(hours: 2)), createdAt: ago(const Duration(days: 3)),
    members: {
      for (final e in names.entries)
        e.key: GroupMember(userId: e.key, name: e.value, avatarUrl: '', joinedAt: ago(const Duration(days: 3)),
            hasApprovedExpense: true),
    },
    memberIds: names.keys.toList(),
  );

  static ExpenseModel _exp(String id, String by, double amount, String comment, Map<String, double> splits,
      Duration age, {String status = 'approved', Map<String, String> approvals = const {}}) =>
      ExpenseModel(
        expenseId: id, groupId: 'g-coxs', loggedBy: by, loggedByName: names[by]!, amount: amount, comment: comment,
        splitType: 'equal',
        splits: {for (final s in splits.entries) s.key: SplitEntry(userId: s.key, name: names[s.key]!, amount: s.value)},
        loggerIncluded: splits.containsKey(by), status: status, createdAt: ago(age), approvals: approvals,
      );

  static final approved = [
    _exp('tuktuk', 'nafis', 600, 'Tuk-tuk to Himchari', {'nafis': 300, 'anika': 300}, const Duration(days: 1, hours: 3)),
    _exp('dinner', 'rafi', 2840, 'Seafood dinner at Poushee',
        {'nafis': 760, 'tasnim': 640, 'rafi': 720, 'anika': 720}, const Duration(days: 2)),
    _exp('hotel', 'tasnim', 12000, 'Sea Pearl resort, 2 nights',
        {'nafis': 3000, 'tasnim': 3000, 'rafi': 3000, 'anika': 3000}, const Duration(days: 2, hours: 5)),
    _exp('bus', 'nafis', 3200, 'Green Line bus tickets',
        {'nafis': 800, 'tasnim': 800, 'rafi': 800, 'anika': 800}, const Duration(days: 3)),
  ];

  static final kayak = _exp('kayak', 'tasnim', 1800, 'Kayaking at Inani', {'tasnim': 600, 'nafis': 600, 'rafi': 600},
      const Duration(hours: 5), status: 'pending', approvals: {'nafis': 'pending', 'rafi': 'approved'});

  static final pastTour = GroupModel(
    groupId: 'g-sylhet', name: 'Sylhet Tea Trail', adminId: 'tasnim', creatorId: 'tasnim',
    currency: 'BDT', currencySymbol: '৳', status: 'inactive', groupCode: 'SY3T8A',
    groupCodeExpiresAt: ago(const Duration(days: 60)), lastActivityAt: ago(const Duration(days: 55)),
    createdAt: ago(const Duration(days: 62)), inactivatedAt: ago(const Duration(days: 54)), inactivatedBy: 'admin',
    members: {
      for (final id in ['tasnim', 'nafis', 'rafi'])
        id: GroupMember(userId: id, name: names[id]!, avatarUrl: '', joinedAt: ago(const Duration(days: 62))),
    },
  );

  static final mine = [
    _exp('snacks', 'nafis', 450, 'Coconuts and jhalmuri', {'nafis': 225, 'anika': 225}, const Duration(hours: 2),
        status: 'pending', approvals: {'anika': 'pending'}),
    ...approved.where((e) => e.loggedBy == 'nafis'),
  ];

  static DebtModel _debt(String exp, String from, String to, double amount, Duration age, {double? remaining}) => DebtModel(
        debtId: '${exp}_$from', groupId: 'g-coxs', fromUserId: from, fromUserName: names[from]!, toUserId: to,
        toUserName: names[to]!, sourceExpenseId: exp, originalAmount: amount, remainingAmount: remaining ?? amount,
        status: 'active', createdAt: ago(age),
      );

  static final iOwe = [
    _debt('hotel', 'nafis', 'tasnim', 3000, const Duration(days: 2, hours: 4)),
    _debt('dinner', 'nafis', 'rafi', 760, const Duration(days: 2)),
  ];

  static final owedToMe = [
    _debt('bus', 'tasnim', 'nafis', 800, const Duration(days: 3)),
    _debt('bus', 'anika', 'nafis', 800, const Duration(days: 3)),
    _debt('tuktuk', 'anika', 'nafis', 300, const Duration(days: 1)),
  ];

  static PaymentModel _pay(String id, String from, String to, String debtId, double amount, Duration age) => PaymentModel(
        paymentId: id, groupId: 'g-coxs', fromUserId: from, fromUserName: names[from]!, toUserId: to,
        toUserName: names[to]!, debtId: debtId, amount: amount, status: 'pending', loggedAt: ago(age),
      );

  static final pendingForMe = [_pay('p2', 'anika', 'nafis', 'bus_anika', 500, const Duration(hours: 3))];
  static final myPayments = [_pay('p3', 'nafis', 'tasnim', 'hotel_nafis', 1000, const Duration(hours: 4))];

  static NotificationModel _n(String id, String type, String ref, String msg, Duration age, {bool read = false}) =>
      NotificationModel(
        notificationId: id, targetUserId: 'nafis', groupId: 'g-coxs', groupName: 'Cox\'s Bazar Getaway',
        type: type, referenceId: ref, message: msg, isRead: read, createdAt: ago(age),
      );

  static final notifications = [
    _n('n3', 'bkash_requested', 'rafi', 'Rafi Hasan is requesting your bKash number', const Duration(minutes: 90)),
    _n('n2', 'payment_pending', 'p2', 'Anika Chowdhury has logged a payment of ৳500.00 to you. Please review.',
        const Duration(hours: 3)),
    _n('n1', 'expense_pending_approval', 'kayak',
        'Tasnim Akter wants to split an expense of ৳600.00 with you. Tap to approve or reject.', const Duration(hours: 5)),
    _n('n4', 'bkash_accepted', 'tasnim', 'Tasnim Akter shared their bKash number with you', const Duration(days: 1),
        read: true),
    _n('n5', 'payment_approved', 'p1', 'Rafi Hasan confirmed your payment of ৳800.00. Debt settled!',
        const Duration(days: 1, hours: 1), read: true),
  ];
}

class FakeAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeGroupService implements GroupService {
  @override
  Stream<List<Map<String, dynamic>>> leaveRequestsStream(String groupId) =>
      Stream.value([{'memberId': 'rafi', 'memberName': 'Rafi Hasan'}]);
  @override
  Future<List<GroupModel>> fetchUserGroupHistory(String userId) async => [Demo.pastTour];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeBkashService implements BkashService {
  @override
  Stream<BkashShare?> shareStream(String groupId, String requesterId, String targetId) => Stream.value(null);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeExpenseService implements ExpenseService {
  @override
  Stream<List<ExpenseModel>> approvedExpensesStream(String groupId) => Stream.value(Demo.approved);
  @override
  Stream<List<ExpenseModel>> myExpensesStream(String groupId, String userId) => Stream.value(Demo.mine);
  @override
  Stream<ExpenseModel> expenseStream(String groupId, String expenseId) => Stream.value(Demo.kayak);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeDebtService implements DebtService {
  @override
  Stream<List<DebtModel>> iOweStream(String groupId, String userId) => Stream.value(Demo.iOwe);
  @override
  Stream<List<DebtModel>> owedToMeStream(String groupId, String userId) => Stream.value(Demo.owedToMe);
  @override
  Stream<List<PaymentModel>> pendingPaymentsForMeStream(String groupId, String userId) => Stream.value(Demo.pendingForMe);
  @override
  Stream<List<PaymentModel>> myPaymentsStream(String groupId, String userId) => Stream.value(Demo.myPayments);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeNotificationService implements NotificationService {
  @override
  Stream<List<NotificationModel>> notificationsStream(String userId) => Stream.value(Demo.notifications);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeGeoService implements GeoService {
  @override
  Future<ExpenseLocation?> captureLocation() async =>
      const ExpenseLocation(latitude: 21.42, longitude: 92.0, address: "Kolatoli Rd, Cox's Bazar");
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
