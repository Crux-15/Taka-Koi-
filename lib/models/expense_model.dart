import 'package:cloud_firestore/cloud_firestore.dart';

/// One member's share in a split expense.
class SplitEntry {
  final String userId;
  final String name;
  final double amount;

  const SplitEntry({
    required this.userId,
    required this.name,
    required this.amount,
  });

  factory SplitEntry.fromMap(String userId, Map<String, dynamic> map) {
    return SplitEntry(
      userId: userId,
      name:   map['name']   as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name':   name,
    'amount': amount,
  };
}

/// GPS location attached to an expense.
class ExpenseLocation {
  final double latitude;
  final double longitude;
  final String? address; // reverse-geocoded display string

  const ExpenseLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory ExpenseLocation.fromMap(Map<String, dynamic> map) {
    return ExpenseLocation(
      latitude:  (map['latitude']  as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address:   map['address']    as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'latitude':  latitude,
    'longitude': longitude,
    'address':   address,
  };

  String get displayAddress => address ?? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

/// Represents a logged expense inside a group.
class ExpenseModel {
  final String expenseId;
  final String groupId;
  final String loggedBy;
  final String loggedByName;
  final double amount;
  final String comment;
  final ExpenseLocation? location;
  final String splitType;           // 'equal' | 'custom'
  final Map<String, SplitEntry> splits; // keyed by userId
  final bool loggerIncluded;
  final String status;              // 'pending' | 'approved'
  final DateTime createdAt;
  final DateTime? approvedAt;

  /// Per-member approval status: uid → 'pending' | 'approved' | 'rejected'
  /// Only populated for split members (not the expense logger).
  final Map<String, String> approvals;

  /// Optional rejection reason per member: uid → reason text
  final Map<String, String> rejectionReasons;

  const ExpenseModel({
    required this.expenseId,
    required this.groupId,
    required this.loggedBy,
    required this.loggedByName,
    required this.amount,
    required this.comment,
    this.location,
    required this.splitType,
    required this.splits,
    required this.loggerIncluded,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.approvals       = const {},
    this.rejectionReasons = const {},
  });

  bool get isPending  => status == 'pending';
  bool get isApproved => status == 'approved';

  /// Returns true if ANY approval is 'rejected'.
  bool get hasRejection => approvals.values.any((v) => v == 'rejected');

  /// Returns true if ALL approvals are 'approved'.
  bool get allApproved  => approvals.isNotEmpty && approvals.values.every((v) => v == 'approved');

  factory ExpenseModel.fromDoc(DocumentSnapshot doc, {String? groupId}) {
    final data = doc.data() as Map<String, dynamic>;

    final rawSplits = (data['splits'] as Map<String, dynamic>?) ?? {};
    final splits    = rawSplits.map(
      (uid, val) => MapEntry(uid, SplitEntry.fromMap(uid, val as Map<String, dynamic>)),
    );

    final locData = data['location'] as Map<String, dynamic>?;

    final rawApprovals = (data['approvals'] as Map<String, dynamic>?) ?? {};
    final approvals    = rawApprovals.map((k, v) => MapEntry(k, v as String? ?? 'pending'));

    final rawReasons = (data['rejectionReasons'] as Map<String, dynamic>?) ?? {};
    final reasons    = rawReasons.map((k, v) => MapEntry(k, v as String? ?? ''));

    return ExpenseModel(
      expenseId:       doc.id,
      groupId:         groupId ?? (data['groupId'] as String? ?? ''),
      loggedBy:        data['loggedBy']       as String? ?? '',
      loggedByName:    data['loggedByName']   as String? ?? '',
      amount:          (data['amount']         as num?)?.toDouble() ?? 0.0,
      comment:         data['comment']        as String? ?? '',
      location:        locData != null ? ExpenseLocation.fromMap(locData) : null,
      splitType:       data['splitType']      as String? ?? 'equal',
      splits:          splits,
      loggerIncluded:  data['loggerIncluded'] as bool? ?? true,
      status:          data['status']         as String? ?? 'pending',
      createdAt:       (data['createdAt']     as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt:      (data['approvedAt']    as Timestamp?)?.toDate(),
      approvals:       approvals,
      rejectionReasons: reasons,
    );
  }

  Map<String, dynamic> toMap() => {
    'loggedBy':        loggedBy,
    'loggedByName':    loggedByName,
    'amount':          amount,
    'comment':         comment,
    'location':        location?.toMap(),
    'splitType':       splitType,
    'splits':          splits.map((k, v) => MapEntry(k, v.toMap())),
    'loggerIncluded':  loggerIncluded,
    'status':          status,
    'createdAt':       Timestamp.fromDate(createdAt),
    'approvedAt':      approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    'approvals':       approvals,
    'rejectionReasons': rejectionReasons,
  };
}
