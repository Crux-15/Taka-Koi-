import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/group_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_exception.dart';
import '../utils/offline.dart';

/// Handles all Firestore operations related to groups.
///
/// Security rules only let members read a group, so someone joining finds it
/// through `groupCodes/{code}` (a code → groupId lookup). Writes never touch
/// another user's profile: each member's app clears its own activeGroupId
/// when it notices the tour has ended or they've been removed.
class GroupService {
  final FirebaseFirestore _db  = FirebaseFirestore.instance;
  final Uuid              _uuid = const Uuid();
  final math.Random       _rng  = math.Random.secure();

  CollectionReference get _groups => _db.collection(AppConstants.colGroups);
  CollectionReference get _codes  => _db.collection(AppConstants.colGroupCodes);
  DocumentReference _user(String uid) => _db.collection(AppConstants.colUsers).doc(uid);

  // ── Group Code ────────────────────────────────────────────────────────────
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      AppConstants.groupCodeLength,
      (_) => chars[_rng.nextInt(chars.length)],
    ).join();
  }

  DateTime _codeExpiry() =>
      DateTime.now().add(const Duration(hours: AppConstants.groupCodeExpiryHours));

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
    final codeExp  = _codeExpiry();

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
      memberIds: [adminId],
    );

    final batch = _db.batch();
    batch.set(_groups.doc(groupId), {
      ...group.toMap(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    batch.set(_codes.doc(code), {
      'groupId':   groupId,
      'expiresAt': Timestamp.fromDate(codeExp),
    });
    batch.update(_user(adminId), {'activeGroupId': groupId});
    await saveOrQueue(batch.commit(), 'createGroup');

    return group;
  }

  // ── Refresh Group Code ────────────────────────────────────────────────────
  /// Admin only. Retires the old code and registers a new one.
  Future<void> refreshGroupCode(String groupId, {String? oldCode}) async {
    final code   = _generateCode();
    final expiry = _codeExpiry();
    final batch  = _db.batch();
    if (oldCode != null && oldCode.isNotEmpty && oldCode != code) {
      batch.delete(_codes.doc(oldCode));
    }
    batch.set(_codes.doc(code), {
      'groupId':   groupId,
      'expiresAt': Timestamp.fromDate(expiry),
    });
    batch.update(_groups.doc(groupId), {
      'groupCode':          code,
      'groupCodeExpiresAt': Timestamp.fromDate(expiry),
    });
    await saveOrQueue(batch.commit(), 'refreshGroupCode');
  }

  // ── Fetch Group by ID ─────────────────────────────────────────────────────
  /// Returns null if the group doesn't exist or you're not allowed to read it
  /// (you're not a member).
  Future<GroupModel?> fetchGroup(String groupId) async {
    try {
      final doc = await _groups.doc(groupId).get();
      if (!doc.exists) return null;
      return GroupModel.fromDoc(doc);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  Stream<GroupModel?> groupStream(String groupId) {
    return _groups.doc(groupId).snapshots().map(
      (doc) => doc.exists ? GroupModel.fromDoc(doc) : null,
    );
  }

  // ── Join Group Directly (no approval needed) ─────────────────────────────
  /// Adds [userId] to the group whose current join code is [code].
  /// Returns the group on success, or null if the code is wrong or expired.
  Future<GroupModel?> joinGroup({
    required String code,
    required String userId,
    required String userName,
    required String avatarUrl,
  }) async {
    final upper   = code.toUpperCase();
    final codeDoc = await _codes.doc(upper).get();
    if (!codeDoc.exists) return null;
    final codeData = codeDoc.data() as Map<String, dynamic>? ?? {};
    final groupId  = codeData['groupId'] as String? ?? '';
    final expires  = (codeData['expiresAt'] as Timestamp?)?.toDate();
    if (groupId.isEmpty) return null;

    // Already a member? Then we can read it, and there's nothing to join.
    final existing = await fetchGroup(groupId);
    if (existing != null && existing.members.containsKey(userId)) {
      if (!existing.isActive) {
        throw const AppException('This tour has already ended.');
      }
      await saveOrQueue(_user(userId).update({'activeGroupId': groupId}), 'joinGroup');
      return existing;
    }
    if (expires != null && DateTime.now().isAfter(expires)) return null;

    final now   = DateTime.now();
    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {
      'members.$userId': {
        ...GroupMember(
          userId:    userId,
          name:      userName,
          avatarUrl: avatarUrl,
          joinedAt:  now,
          hasApprovedExpense: false,
        ).toMap(),
        // The rules check this against the group's current code.
        'joinCode': upper,
      },
      'memberIds':      FieldValue.arrayUnion([userId]),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    batch.update(_user(userId), {'activeGroupId': groupId});

    try {
      await saveOrQueue(batch.commit(), 'joinGroup');
    } on FirebaseException catch (e) {
      // The code changed, expired or the tour ended since we looked it up.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
    return fetchGroup(groupId);
  }

  // ── Remove Member ─────────────────────────────────────────────────────────
  /// Admin can only remove a member who has NO approved expenses
  /// (hasApprovedExpense == false). Their app notices and clears their own
  /// active tour.
  Future<void> removeMember({required String groupId, required String memberId}) async {
    await saveOrQueue(_groups.doc(groupId).update({
      'members.$memberId': FieldValue.delete(),
      'memberIds':         FieldValue.arrayRemove([memberId]),
    }), 'removeMember');
  }

  // ── Transfer Admin ────────────────────────────────────────────────────────
  Future<void> transferAdmin({required String groupId, required String newAdminId}) async {
    await saveOrQueue(_groups.doc(groupId).update({'adminId': newAdminId}), 'transferAdmin');
  }

  // ── Deactivate Group ──────────────────────────────────────────────────────
  /// The admin ends the tour. Each member's app clears its own active tour
  /// when it sees the status change. (Idle tours go through [autoEndIfIdle].)
  Future<void> deactivateGroup({required String groupId}) async {
    await saveOrQueue(_groups.doc(groupId).update({
      'status':        AppConstants.statusInactive,
      'inactivatedAt': FieldValue.serverTimestamp(),
      'inactivatedBy': AppConstants.inactivatedByAdmin,
    }), 'deactivateGroup');
  }

  /// Ends an idle tour, but only as a transaction against the server's copy.
  ///
  /// Nothing changes on this phone unless the server accepts it, and the
  /// rules check the 4 days against the server clock. So a phone with a wrong
  /// clock or old cached data can't end a tour, not even briefly on screen.
  /// Returns true if this call ended the tour.
  Future<bool> autoEndIfIdle(String groupId) async {
    await requireConnection();
    return _db.runTransaction<bool>(timeout: transactionTimeout, (tx) async {
      final snap = await tx.get(_groups.doc(groupId));
      if (!snap.exists) return false;
      final group = GroupModel.fromDoc(snap);
      if (!group.isActive) return false;
      final idleDays = DateTime.now().difference(group.lastActivityAt).inDays;
      if (idleDays < AppConstants.inactivityDays) return false;
      tx.update(snap.reference, {
        'status':        AppConstants.statusInactive,
        'inactivatedAt': FieldValue.serverTimestamp(),
        'inactivatedBy': AppConstants.inactivatedBySystem,
      });
      return true;
    });
  }

  // ── Update Last Activity ──────────────────────────────────────────────────
  Future<void> touchLastActivity(String groupId) async {
    await saveOrQueue(_groups.doc(groupId).update({'lastActivityAt': FieldValue.serverTimestamp()}), 'touchLastActivity');
  }

  /// Fills in memberIds for groups created before it existed.
  Future<void> backfillMemberIds(String groupId, List<String> memberIds) async {
    await saveOrQueue(_groups.doc(groupId).update({'memberIds': memberIds}), 'backfillMemberIds');
  }

  /// Clears the signed-in user's active tour if it still points at [groupId].
  Future<void> clearActiveGroup({required String userId, required String groupId}) async {
    final snap = await _user(userId).get();
    final data = snap.data() as Map<String, dynamic>?;
    if (data?['activeGroupId'] == groupId) {
      await saveOrQueue(_user(userId).update({'activeGroupId': null}), 'clearActiveGroup');
    }
  }

  // ── Open items ───────────────────────────────────────────────────────────
  /// What still ties [userId] to a tour: debts they owe or are owed that aren't
  /// settled, and expenses waiting on them (to approve, or that they logged).
  /// Leaving with any of these would leave them stuck: once you're out of a
  /// tour you can't see or settle its money.
  Future<({int owes, int owed, int pending})> openItemsFor(String groupId, String userId) async {
    final debts = _groups.doc(groupId).collection(AppConstants.colDebts);
    bool open(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final m = d.data();
      return m['status'] == AppConstants.statusActive && ((m['remainingAmount'] as num?) ?? 0) >= 0.01;
    }

    final results = await Future.wait([
      debts.where('fromUserId', isEqualTo: userId).get(),
      debts.where('toUserId', isEqualTo: userId).get(),
      _groups.doc(groupId).collection(AppConstants.colExpenses)
          .where('status', isEqualTo: AppConstants.statusPending).get(),
    ]);
    final pending = results[2].docs.where((d) {
      final m = d.data();
      final approvals = (m['approvals'] as Map<String, dynamic>?) ?? const {};
      return m['loggedBy'] == userId || approvals.containsKey(userId);
    }).length;
    return (
      owes:    results[0].docs.where(open).length,
      owed:    results[1].docs.where(open).length,
      pending: pending,
    );
  }

  /// Unsettled debts in the whole tour (shown before the admin ends it).
  Future<int> openDebtCount(String groupId) async {
    final snap = await _groups.doc(groupId).collection(AppConstants.colDebts)
        .where('status', isEqualTo: AppConstants.statusActive).get();
    return snap.docs.where((d) => ((d.data()['remainingAmount'] as num?) ?? 0) >= 0.01).length;
  }

  // ── Leave Request (member-initiated) ─────────────────────────────────────
  /// Writes a leave request document to groups/{gid}/leaveRequests/{uid}.
  Future<void> requestLeave({
    required String groupId,
    required String memberId,
    required String memberName,
  }) async {
    await saveOrQueue(_groups.doc(groupId).collection('leaveRequests').doc(memberId).set({
      'memberId':   memberId,
      'memberName': memberName,
      'status':     'pending',
      'requestedAt': Timestamp.now(),
    }), 'requestLeave');
  }

  /// Admin approves: removes the member. Their app clears its own active tour.
  Future<void> approveLeave({required String groupId, required String memberId}) async {
    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {
      'members.$memberId': FieldValue.delete(),
      'memberIds':         FieldValue.arrayRemove([memberId]),
    });
    batch.delete(_groups.doc(groupId).collection('leaveRequests').doc(memberId));
    await saveOrQueue(batch.commit(), 'approveLeave');
  }

  /// Admin rejects: delete the leave request.
  Future<void> rejectLeave({required String groupId, required String memberId}) async {
    await saveOrQueue(_groups.doc(groupId).collection('leaveRequests').doc(memberId).delete(), 'rejectLeave');
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
  /// Removes the user from the ended group's members so it no longer appears
  /// in their history. The group document is preserved for others.
  Future<void> removeFromHistory({
    required String groupId,
    required String userId,
  }) async {
    await saveOrQueue(_groups.doc(groupId).update({
      'members.$userId': FieldValue.delete(),
      'memberIds':       FieldValue.arrayRemove([userId]),
    }), 'removeFromHistory');
  }

  // ── History Groups ────────────────────────────────────────────────────────
  /// Ended tours this user was in. Only queries the user's own groups; the
  /// status filter and sort happen here to avoid needing a composite index.
  Future<List<GroupModel>> fetchUserGroupHistory(String userId) async {
    final query = await _groups
        .where('memberIds', arrayContains: userId)
        .get();
    return query.docs
        .map(GroupModel.fromDoc)
        .where((g) => g.isInactive && g.members.containsKey(userId))
        .toList()
      ..sort((a, b) => (b.inactivatedAt ?? DateTime(0)).compareTo(a.inactivatedAt ?? DateTime(0)));
  }
}
