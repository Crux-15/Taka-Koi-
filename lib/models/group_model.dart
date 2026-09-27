import 'package:cloud_firestore/cloud_firestore.dart';

/// Embedded member entry inside a group document.
class GroupMember {
  final String userId;
  final String name;
  final String avatarUrl;
  final DateTime joinedAt;
  final bool hasApprovedExpense; // gates kick permission

  const GroupMember({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.joinedAt,
    this.hasApprovedExpense = false,
  });

  factory GroupMember.fromMap(String userId, Map<String, dynamic> map) {
    return GroupMember(
      userId:              userId,
      name:                map['name']                as String? ?? '',
      avatarUrl:           map['avatarUrl']            as String? ?? '',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasApprovedExpense:  map['hasApprovedExpense']   as bool?   ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name':               name,
    'avatarUrl':          avatarUrl,
    'joinedAt':           Timestamp.fromDate(joinedAt),
    'hasApprovedExpense': hasApprovedExpense,
  };

  GroupMember copyWith({bool? hasApprovedExpense}) => GroupMember(
    userId:              userId,
    name:                name,
    avatarUrl:           avatarUrl,
    joinedAt:            joinedAt,
    hasApprovedExpense:  hasApprovedExpense ?? this.hasApprovedExpense,
  );
}

/// Represents a travel group document.
class GroupModel {
  final String groupId;
  final String name;
  final String adminId;
  final String creatorId;
  final String currency;
  final String currencySymbol;
  final String status;       // 'active' | 'inactive'
  final String groupCode;
  final DateTime groupCodeExpiresAt;
  final DateTime lastActivityAt;
  final DateTime createdAt;
  final DateTime? inactivatedAt;
  final String? inactivatedBy;   // 'admin' | 'system'
  final Map<String, GroupMember> members; // keyed by userId

  const GroupModel({
    required this.groupId,
    required this.name,
    required this.adminId,
    required this.creatorId,
    required this.currency,
    required this.currencySymbol,
    required this.status,
    required this.groupCode,
    required this.groupCodeExpiresAt,
    required this.lastActivityAt,
    required this.createdAt,
    this.inactivatedAt,
    this.inactivatedBy,
    required this.members,
  });

  bool get isActive   => status == 'active';
  bool get isInactive => status == 'inactive';

  bool get isCodeExpired => DateTime.now().isAfter(groupCodeExpiresAt);

  factory GroupModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Parse embedded members map
    final rawMembers = (data['members'] as Map<String, dynamic>?) ?? {};
    final members = rawMembers.map(
      (uid, val) => MapEntry(uid, GroupMember.fromMap(uid, val as Map<String, dynamic>)),
    );
    return GroupModel(
      groupId:            doc.id,
      name:               data['name']               as String? ?? '',
      adminId:            data['adminId']             as String? ?? '',
      creatorId:          data['creatorId']           as String? ?? '',
      currency:           data['currency']            as String? ?? 'BDT',
      currencySymbol:     data['currencySymbol']      as String? ?? '৳',
      status:             data['status']              as String? ?? 'active',
      groupCode:          data['groupCode']           as String? ?? '',
      groupCodeExpiresAt: (data['groupCodeExpiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivityAt:     (data['lastActivityAt']     as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:          (data['createdAt']          as Timestamp?)?.toDate() ?? DateTime.now(),
      inactivatedAt:      (data['inactivatedAt']      as Timestamp?)?.toDate(),
      inactivatedBy:      data['inactivatedBy']       as String?,
      members:            members,
    );
  }

  Map<String, dynamic> toMap() => {
    'name':               name,
    'adminId':            adminId,
    'creatorId':          creatorId,
    'currency':           currency,
    'currencySymbol':     currencySymbol,
    'status':             status,
    'groupCode':          groupCode,
    'groupCodeExpiresAt': Timestamp.fromDate(groupCodeExpiresAt),
    'lastActivityAt':     Timestamp.fromDate(lastActivityAt),
    'createdAt':          Timestamp.fromDate(createdAt),
    'inactivatedAt':      inactivatedAt != null ? Timestamp.fromDate(inactivatedAt!) : null,
    'inactivatedBy':      inactivatedBy,
    'members':            members.map((k, v) => MapEntry(k, v.toMap())),
  };

  GroupModel copyWith({
    String? adminId,
    String? status,
    String? groupCode,
    DateTime? groupCodeExpiresAt,
    DateTime? lastActivityAt,
    DateTime? inactivatedAt,
    String? inactivatedBy,
    Map<String, GroupMember>? members,
  }) {
    return GroupModel(
      groupId:            groupId,
      name:               name,
      adminId:            adminId            ?? this.adminId,
      creatorId:          creatorId,
      currency:           currency,
      currencySymbol:     currencySymbol,
      status:             status             ?? this.status,
      groupCode:          groupCode          ?? this.groupCode,
      groupCodeExpiresAt: groupCodeExpiresAt ?? this.groupCodeExpiresAt,
      lastActivityAt:     lastActivityAt     ?? this.lastActivityAt,
      createdAt:          createdAt,
      inactivatedAt:      inactivatedAt      ?? this.inactivatedAt,
      inactivatedBy:      inactivatedBy      ?? this.inactivatedBy,
      members:            members            ?? this.members,
    );
  }
}

/// Join request from a user wanting to join a group.
class JoinRequest {
  final String requestId;
  final String userId;
  final String userName;
  final String avatarUrl;
  final String status;     // 'pending' | 'approved' | 'rejected'
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  const JoinRequest({
    required this.requestId,
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
  });

  factory JoinRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JoinRequest(
      requestId:   doc.id,
      userId:      data['userId']      as String? ?? '',
      userName:    data['userName']    as String? ?? '',
      avatarUrl:   data['avatarUrl']   as String? ?? '',
      status:      data['status']      as String? ?? 'pending',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt:  (data['resolvedAt']  as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId':      userId,
    'userName':    userName,
    'avatarUrl':   avatarUrl,
    'status':      status,
    'requestedAt': Timestamp.fromDate(requestedAt),
    'resolvedAt':  resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
  };
}
