import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/money.dart';

/// Represents a single debt record: one person owes another.
class DebtModel {
  final String debtId;
  final String groupId;
  final String fromUserId;   // who owes
  final String fromUserName;
  final String toUserId;     // who is owed
  final String toUserName;
  final String sourceExpenseId;
  final double originalAmount;
  final double remainingAmount; // decreases on partial payments
  final String status;          // 'active' | 'settled'
  final DateTime createdAt;
  final DateTime? settledAt;

  const DebtModel({
    required this.debtId,
    required this.groupId,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.sourceExpenseId,
    required this.originalAmount,
    required this.remainingAmount,
    required this.status,
    required this.createdAt,
    this.settledAt,
  });

  bool get isActive   => status == 'active';
  bool get isSettled  => status == 'settled';

  /// Remaining amount in whole cents.
  int get remainingCents => Money.toCents(remainingAmount);

  /// True while there is at least one cent left to pay. Older debts can be
  /// "active" with only a fraction of a cent left (from unrounded splits);
  /// those count as paid off.
  bool get isOpen => isActive && remainingCents > 0;

  factory DebtModel.fromDoc(DocumentSnapshot doc, {String? groupId}) {
    final data = doc.data() as Map<String, dynamic>;
    return DebtModel(
      debtId:           doc.id,
      groupId:          groupId ?? (data['groupId'] as String? ?? ''),
      fromUserId:       data['fromUserId']       as String? ?? '',
      fromUserName:     data['fromUserName']     as String? ?? '',
      toUserId:         data['toUserId']         as String? ?? '',
      toUserName:       data['toUserName']       as String? ?? '',
      sourceExpenseId:  data['sourceExpenseId']  as String? ?? '',
      originalAmount:   (data['originalAmount']  as num?)?.toDouble() ?? 0.0,
      remainingAmount:  (data['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      status:           data['status']           as String? ?? 'active',
      createdAt:  (data['createdAt']  as Timestamp?)?.toDate() ?? DateTime.now(),
      settledAt:  (data['settledAt']  as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'fromUserId':      fromUserId,
    'fromUserName':    fromUserName,
    'toUserId':        toUserId,
    'toUserName':      toUserName,
    'sourceExpenseId': sourceExpenseId,
    'originalAmount':  originalAmount,
    'remainingAmount': remainingAmount,
    'status':          status,
    'createdAt':       Timestamp.fromDate(createdAt),
    'settledAt':       settledAt != null ? Timestamp.fromDate(settledAt!) : null,
  };

  DebtModel copyWith({
    double? remainingAmount,
    String? status,
    DateTime? settledAt,
  }) {
    return DebtModel(
      debtId:           debtId,
      groupId:          groupId,
      fromUserId:       fromUserId,
      fromUserName:     fromUserName,
      toUserId:         toUserId,
      toUserName:       toUserName,
      sourceExpenseId:  sourceExpenseId,
      originalAmount:   originalAmount,
      remainingAmount:  remainingAmount  ?? this.remainingAmount,
      status:           status          ?? this.status,
      createdAt:        createdAt,
      settledAt:        settledAt       ?? this.settledAt,
    );
  }
}
