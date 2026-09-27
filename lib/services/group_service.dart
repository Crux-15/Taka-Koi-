import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/group_model.dart';
import '../utils/app_constants.dart';

/// Handles all Firestore operations related to groups and join requests.
class GroupService {
  final FirebaseFirestore _db  = FirebaseFirestore.instance;
  final Uuid              _uuid = const Uuid();
  final math.Random       _rng  = math.Random.secure();

  CollectionReference get _groups => _db.collection(AppConstants.colGroups);

  // ── Group Code ────────────────────────────────────────────────────────────
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      AppConstants.groupCodeLength,
      (_) => chars[_rng.nextInt(chars.length)],
    ).join();
  }

  // ── Create Group ──────────────────────────────────────────────────────────
  Future<GroupModel> createGroup({
    required String adminId,
    required String adminName,
    required String adminAvatar,
    required String groupName,
    required String currency,
    required String currencySymbol,
  }) async {
    final groupId  = _uuid.v4();
    final code     = _generateCode();
    final now      = DateTime.now();
    final codeExp  = now.add(const Duration(hours: AppConstants.groupCodeExpiryHours));

    final group = GroupModel(
      groupId:            groupId,
      name:               groupName,
      adminId:            adminId,
      creatorId:          adminId,
      currency:           currency,
      currencySymbol:     currencySymbol,
      status:             AppConstants.statusActive,
      groupCode:          code,
      groupCodeExpiresAt: codeExp,
      lastActivityAt:     now,
      createdAt:          now,
      members: {
        adminId: GroupMember(
          userId:    adminId,
          name:      adminName,
          avatarUrl: adminAvatar,
          joinedAt:  now,
          hasApprovedExpense: false,
        ),
      },
    );

    await _groups.doc(groupId).set(group.toMap());

    // Set admin's activeGroupId
    await _db.collection(AppConstants.colUsers).doc(adminId).update({'activeGroupId': groupId});

    return group;
  }

  // ── Refresh Group Code ────────────────────────────────────────────────────
  Future<void> refreshGroupCode(String groupId) async {
    final code   = _generateCode();
    final expiry = DateTime.now().add(const Duration(hours: AppConstants.groupCodeExpiryHours));
    await _groups.doc(groupId).update({
      'groupCode':           code,
      'groupCodeExpiresAt':  Timestamp.fromDate(expiry),
    });
  }

  // ── Fetch Group by Code ───────────────────────────────────────────────────
  /// Uses single-field query (no composite index needed) then filters status in Dart.
  Future<GroupModel?> fetchGroupByCode(String code) async {
    final query = await _groups
        .where('groupCode', isEqualTo: code)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final group = GroupModel.fromDoc(query.docs.first);
    // Check status in Dart — avoids needing a Firestore composite index
    if (!group.isActive) return null;
    return group;
  }

  // ── Fetch Group by ID ─────────────────────────────────────────────────────
  Future<GroupModel?> fetchGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupModel.fromDoc(doc);
  }

  Stream<GroupModel?> groupStream(String groupId) {
    return _groups.doc(groupId).snapshots().map(
      (doc) => doc.exists ? GroupModel.fromDoc(doc) : null,
    );
  }

  // ── Join Group Directly (no approval needed) ─────────────────────────────
  /// Instantly adds [userId] as a member of the group identified by [code].
  /// Returns the [GroupModel] on success, null if code is invalid/expired.
  Future<GroupModel?> joinGroup({
    required String code,
    required String userId,
    required String userName,
    required String avatarUrl,
  }) async {
    final group = await fetchGroupByCode(code.toUpperCase());
    if (group == null) return null;
    if (group.isCodeExpired) return null;
    if (group.members.containsKey(userId)) return group; // already a member

    final now = DateTime.now();
    final batch = _db.batch();
    final groupRef = _groups.doc(group.groupId);

    // Add member directly to the group document
    batch.update(groupRef, {
      'members.$userId': GroupMember(
        userId:    userId,
        name:      userName,
        avatarUrl: avatarUrl,
        joinedAt:  now,
        hasApprovedExpense: false,
      ).toMap(),
      'lastActivityAt': Timestamp.fromDate(now),
    });

    // Set member's activeGroupId
    batch.update(
      _db.collection(AppConstants.colUsers).doc(userId),
      {'activeGroupId': group.groupId},
    );

    await batch.commit();
    return group;
  }

  // ── Remove Member ─────────────────────────────────────────────────────────
  /// Admin can only remove a member who has NO approved expenses (hasApprovedExpense == false).
  Future<void> removeMember({required String groupId, required String memberId}) async {
    final batch = _db.batch();
    final groupRef = _groups.doc(groupId);
    batch.update(groupRef, {'members.$memberId': FieldValue.delete()});
    batch.update(
      _db.collection(AppConstants.colUsers).doc(memberId),
      {'activeGroupId': null},
    );
    await batch.commit();
  }

  // ── Transfer Admin ────────────────────────────────────────────────────────
  Future<void> transferAdmin({required String groupId, required String newAdminId}) async {
    await _groups.doc(groupId).update({'adminId': newAdminId});
  }

  // ── Deactivate Group ──────────────────────────────────────────────────────
  Future<void> deactivateGroup({
    required String groupId,
    required String reason, // 'admin' | 'system'
    required List<String> memberIds,
  }) async {
    final batch = _db.batch();
    final groupRef = _groups.doc(groupId);
    batch.update(groupRef, {
      'status':        AppConstants.statusInactive,
      'inactivatedAt': Timestamp.now(),
      'inactivatedBy': reason,
    });
    // Clear activeGroupId for all members
    for (final uid in memberIds) {
      batch.update(
        _db.collection(AppConstants.colUsers).doc(uid),
        {'activeGroupId': null},
      );
    }
    await batch.commit();
  }

  // ── Update Last Activity ──────────────────────────────────────────────────
  Future<void> touchLastActivity(String groupId) async {
    await _groups.doc(groupId).update({'lastActivityAt': Timestamp.now()});
  }

  // ── Leave Request (member-initiated) ─────────────────────────────────────
  /// Writes a leave request document to groups/{gid}/leaveRequests/{uid}.
  Future<void> requestLeave({
    required String groupId,
    required String memberId,
    required String memberName,
  }) async {
    await _groups.doc(groupId).collection('leaveRequests').doc(memberId).set({
      'memberId':   memberId,
      'memberName': memberName,
      'status':     'pending',
      'requestedAt': Timestamp.now(),
    });
  }

  /// Admin approves: remove member from group, clear activeGroupId.
  Future<void> approveLeave({required String groupId, required String memberId}) async {
    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {'members.$memberId': FieldValue.delete()});
    batch.update(_db.collection(AppConstants.colUsers).doc(memberId), {'activeGroupId': null});
    batch.delete(_groups.doc(groupId).collection('leaveRequests').doc(memberId));
    await batch.commit();
  }

  /// Admin rejects: delete the leave request.
  Future<void> rejectLeave({required String groupId, required String memberId}) async {
    await _groups.doc(groupId).collection('leaveRequests').doc(memberId).delete();
  }

  /// Stream of pending leave requests for a group (admin only).
  Stream<List<Map<String, dynamic>>> leaveRequestsStream(String groupId) {
    return _groups
        .doc(groupId)
        .collection('leaveRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  // ── Remove from History (user hides a past group) ────────────────────────
  /// Removes the user from the inactive group's members map so it no longer
  /// appears in their history. The group document is preserved for others.
  Future<void> removeFromHistory({
    required String groupId,
    required String userId,
  }) async {
    await _groups.doc(groupId).update({'members.$userId': FieldValue.delete()});
  }

  // ── History Groups ────────────────────────────────────────────────────────
  Future<List<GroupModel>> fetchUserGroupHistory(String userId) async {
    // Query only by single field to avoid needing a composite Firestore index.
    // Filter status and sort by inactivatedAt in Dart.
    final query = await _groups
        .where('status', isEqualTo: AppConstants.statusInactive)
        .get();
    return query.docs
        .map(GroupModel.fromDoc)
        .where((g) => g.members.containsKey(userId))
        .toList()
      ..sort((a, b) => (b.inactivatedAt ?? DateTime(0)).compareTo(a.inactivatedAt ?? DateTime(0)));
  }
}
