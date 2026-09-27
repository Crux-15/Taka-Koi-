import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment log from a payer to a receiver (debt settlement).
class PaymentModel {
  final String paymentId;
  final String groupId;
  final String fromUserId;    // payer
  final String fromUserName;
  final String toUserId;      // receiver
  final String toUserName;
  final String debtId;
  final double amount;
  final String? bkashNumber;  // receiver's bkash at time of payment (audit copy)
  final String status;        // 'pending' | 'approved' | 'rejected'
  final String? rejectionNote;
  final DateTime loggedAt;
  final DateTime? approvedAt;
  final DateTime? resubmittedAt;

  const PaymentModel({
    required this.paymentId,
    required this.groupId,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.debtId,
    required this.amount,
    this.bkashNumber,
    required this.status,
    this.rejectionNote,
    required this.loggedAt,
    this.approvedAt,
    this.resubmittedAt,
  });

  bool get isPending  => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory PaymentModel.fromDoc(DocumentSnapshot doc, {String? groupId}) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      paymentId:     doc.id,
      groupId:       groupId ?? (data['groupId'] as String? ?? ''),
      fromUserId:    data['fromUserId']    as String? ?? '',
      fromUserName:  data['fromUserName']  as String? ?? '',
      toUserId:      data['toUserId']      as String? ?? '',
      toUserName:    data['toUserName']    as String? ?? '',
      debtId:        data['debtId']        as String? ?? '',
      amount:        (data['amount']        as num?)?.toDouble() ?? 0.0,
      bkashNumber:   data['bkashNumber']   as String?,
      status:        data['status']        as String? ?? 'pending',
      rejectionNote: data['rejectionNote'] as String?,
      loggedAt:      (data['loggedAt']     as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt:    (data['approvedAt']   as Timestamp?)?.toDate(),
      resubmittedAt: (data['resubmittedAt']as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'fromUserId':    fromUserId,
    'fromUserName':  fromUserName,
    'toUserId':      toUserId,
    'toUserName':    toUserName,
    'debtId':        debtId,
    'amount':        amount,
    'bkashNumber':   bkashNumber,
    'status':        status,
    'rejectionNote': rejectionNote,
    'loggedAt':      Timestamp.fromDate(loggedAt),
    'approvedAt':    approvedAt    != null ? Timestamp.fromDate(approvedAt!)    : null,
    'resubmittedAt': resubmittedAt != null ? Timestamp.fromDate(resubmittedAt!) : null,
  };
}
