import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_model.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import '../utils/app_constants.dart';

enum GroupStatus { initial, loading, loaded, error }

/// Controller for group management operations.
class GroupController extends ChangeNotifier {
  final GroupService        _groupService = GroupService();
  final NotificationService _notifService = NotificationService();

  GroupStatus  _status       = GroupStatus.initial;
  GroupModel?  _activeGroup;
  String?      _errorMessage;
  List<GroupModel> _history  = [];
  StreamSubscription<GroupModel?>? _groupSub;
  bool _refreshingCode = false;
  String? _currentUserId; // stored so stream can detect when THIS user is removed

  GroupStatus       get status          => _status;
  GroupModel?       get activeGroup     => _activeGroup;
  String?           get errorMessage    => _errorMessage;
  List<GroupModel>  get history         => _history;
  bool get isLoading        => _status == GroupStatus.loading;
  bool get hasActiveGroup   => _activeGroup != null && _activeGroup!.isActive;
  bool get isRefreshingCode => _refreshingCode;

  // ── Load Active Group ─────────────────────────────────────────────────────
  /// [currentUserId] — the UID of the signed-in user.  Must be supplied so
  /// the stream can detect when that user is removed from the group (leave
  /// approved) and redirect them without requiring an app restart.
  void listenToGroup(String groupId, {String? currentUserId}) {
    if (currentUserId != null) _currentUserId = currentUserId;
    _groupSub?.cancel();
    _groupSub = _groupService.groupStream(groupId).listen((group) {
      if (group == null) {
        // Group document was deleted — treat as deactivated
        _handleRemovedFromGroup();
        return;
      }

      // If the group is still active but THIS user is no longer in members,
      // the admin approved their leave request on another device.
      if (group.isActive &&
          _currentUserId != null &&
          !group.members.containsKey(_currentUserId)) {
        _handleRemovedFromGroup();
        return;
      }

      _activeGroup = group;
      _status      = GroupStatus.loaded;

      // If the group just became inactive (admin ended it on another device),
      // proactively load history so Past Tours shows immediately on redirect.
      if (!group.isActive && _currentUserId != null) {
        loadHistory(_currentUserId!); // fire-and-forget; notifyListeners handles redirect
      }

      notifyListeners();
      if (group.isActive) _checkInactivity(group);
    });
  }

  /// Called when the current user is kicked out or their leave is approved.
  /// Clears all group state and triggers a router redirect to the group hub.
  Future<void> _handleRemovedFromGroup() async {
    _groupSub?.cancel();
    _groupSub = null;
    _activeGroup = null;
    _status = GroupStatus.initial;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeGroupId');
    // Reload history so the freshly-navigated GroupHubView shows past tours
    if (_currentUserId != null) {
      await loadHistory(_currentUserId!);
    }
    notifyListeners(); // triggers router hasActiveGroup = false → /groupHub
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    super.dispose();
  }

  /// Called on sign-out — cancels the stream and clears in-memory group state
  /// so the router's hasActiveGroup guard works correctly on the next login.
  void clearGroup() {
    _groupSub?.cancel();
    _groupSub = null;
    _activeGroup = null;
    _currentUserId = null;
    _status = GroupStatus.initial;
    notifyListeners();
  }

  void _checkInactivity(GroupModel group) {
    final daysSinceLast = DateTime.now().difference(group.lastActivityAt).inDays;
    if (daysSinceLast >= AppConstants.inactivityDays) {
      deactivateGroup(
        groupId:  group.groupId,
        reason:   AppConstants.inactivatedBySystem,
        memberIds: group.members.keys.toList(),
      );
    }
  }

  // ── Create Group ──────────────────────────────────────────────────────────
  Future<GroupModel?> createGroup({
    required String adminId,
    required String adminName,
    required String adminAvatar,
    required String groupName,
    required String currency,
    required String currencySymbol,
  }) async {
    _setLoading();
    try {
      final group = await _groupService.createGroup(
        adminId:        adminId,
        adminName:      adminName,
        adminAvatar:    adminAvatar,
        groupName:      groupName,
        currency:       currency,
        currencySymbol: currencySymbol,
      );
      // Start real-time stream IMMEDIATELY so refreshGroupCode() and member
      // join events are reflected without needing an app restart.
      listenToGroup(group.groupId, currentUserId: adminId);
      return group;
    } catch (e) {
      _setError('Failed to create group. Please try again.');
      return null;
    }
  }

  // ── Join via Code (instant, no approval) ─────────────────────────────────
  Future<bool> joinGroup({
    required String code,
    required String userId,
    required String userName,
    required String avatarUrl,
  }) async {
    _setLoading();
    try {
      final group = await _groupService.joinGroup(
        code:      code,
        userId:    userId,
        userName:  userName,
        avatarUrl: avatarUrl,
      );
      if (group == null) {
        _setError('Invalid or expired group code. Ask the group creator to refresh it.');
        return false;
      }
      // Start listening to the group stream so state is live
      listenToGroup(group.groupId, currentUserId: userId);
      _status = GroupStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to join group. Please try again.');
      return false;
    }
  }


  // ── Admin: Refresh Code ───────────────────────────────────────────────────
  Future<void> refreshGroupCode() async {
    if (_activeGroup == null || _refreshingCode) return;
    _refreshingCode = true;
    notifyListeners();
    try {
      await _groupService.refreshGroupCode(_activeGroup!.groupId);
      // The Firestore stream will auto-update _activeGroup with the new code
    } finally {
      _refreshingCode = false;
      notifyListeners();
    }
  }

  // ── Admin: Remove Member ──────────────────────────────────────────────────
  Future<bool> removeMember(String memberId) async {
    if (_activeGroup == null) return false;
    final member = _activeGroup!.members[memberId];
    if (member == null) return false;
    if (member.hasApprovedExpense) return false; // cannot remove
    await _groupService.removeMember(groupId: _activeGroup!.groupId, memberId: memberId);
    return true;
  }

  // ── Admin: Transfer Admin Role ────────────────────────────────────────────
  Future<void> transferAdmin(String newAdminId) async {
    if (_activeGroup == null) return;
    await _groupService.transferAdmin(groupId: _activeGroup!.groupId, newAdminId: newAdminId);
    await _notifService.send(
      targetUserId: newAdminId,
      groupId:      _activeGroup!.groupId,
      type:         AppConstants.notifAdminTransferRequired,
      referenceId:  _activeGroup!.groupId,
      message:      'You are now the admin of ${_activeGroup!.name}.',
    );
  }

  // ── Deactivate Group ──────────────────────────────────────────────────────
  Future<void> deactivateGroup({
    required String groupId,
    required String reason,
    required List<String> memberIds,
    String groupName = '',
  }) async {
    await _groupService.deactivateGroup(
      groupId:   groupId,
      reason:    reason,
      memberIds: memberIds,
    );
    // Notify ALL members that the group ended (so their devices react via stream)
    final msg = reason == AppConstants.inactivatedBySystem
        ? 'Your tour "$groupName" was automatically ended due to 4 days of inactivity.'
        : 'Your tour "$groupName" has been ended by the admin.';
    await _notifService.sendToMany(
      targetUserIds: memberIds,
      groupId:       groupId,
      type:          reason == AppConstants.inactivatedBySystem
          ? AppConstants.notifGroupAutoDeactivated
          : AppConstants.notifGroupEnded,
      referenceId:   groupId,
      message:       msg,
    );
    // Clear persisted group ID so re-opening doesn't try to restore a dead group
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeGroupId');

    // Proactively load history for the admin so Past Tours shows immediately
    if (_currentUserId != null) {
      await loadHistory(_currentUserId!);
    }
    _activeGroup = null;
    notifyListeners();
  }

  // ── Leave Group (member-initiated, requires admin approval) ───────────────
  Future<bool> requestLeave({required String userId, required String userName}) async {
    if (_activeGroup == null) return false;
    try {
      await _groupService.requestLeave(
        groupId:    _activeGroup!.groupId,
        memberId:   userId,
        memberName: userName,
      );
      // Notify admin
      await _notifService.send(
        targetUserId: _activeGroup!.adminId,
        groupId:      _activeGroup!.groupId,
        type:         AppConstants.notifLeaveRequest,
        referenceId:  userId,
        message:      '$userName has requested to leave the group "${_activeGroup!.name}". Tap to review.',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> approveLeave({required String memberId, required String memberName}) async {
    if (_activeGroup == null) return false;
    try {
      await _groupService.approveLeave(groupId: _activeGroup!.groupId, memberId: memberId);
      await _notifService.send(
        targetUserId: memberId,
        groupId:      _activeGroup!.groupId,
        type:         AppConstants.notifLeaveApproved,
        referenceId:  _activeGroup!.groupId,
        message:      'Your request to leave "${_activeGroup!.name}" has been approved.',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectLeave({required String memberId, required String memberName}) async {
    if (_activeGroup == null) return false;
    try {
      await _groupService.rejectLeave(groupId: _activeGroup!.groupId, memberId: memberId);
      await _notifService.send(
        targetUserId: memberId,
        groupId:      _activeGroup!.groupId,
        type:         AppConstants.notifLeaveRejected,
        referenceId:  _activeGroup!.groupId,
        message:      'Your request to leave "${_activeGroup!.name}" was rejected by the admin.',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> leaveRequestsStream() {
    if (_activeGroup == null) return const Stream.empty();
    return _groupService.leaveRequestsStream(_activeGroup!.groupId);
  }

  // ── Remove from History ───────────────────────────────────────────────────
  Future<void> removeFromHistory({required String groupId, required String userId}) async {
    await _groupService.removeFromHistory(groupId: groupId, userId: userId);
    // Remove locally so the list updates instantly without re-fetching
    _history.removeWhere((g) => g.groupId == groupId);
    notifyListeners();
  }

  // ── Load History ──────────────────────────────────────────────────────────
  Future<void> loadHistory(String userId) async {
    try {
      _history = await _groupService.fetchUserGroupHistory(userId);
      notifyListeners();
    } catch (_) {}
  }



  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setLoading() {
    _status       = GroupStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status       = GroupStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _status       = GroupStatus.loaded;
    notifyListeners();
  }

  // ── bKash Number Sharing ──────────────────────────────────────────────────

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sends a bKash number request from [requesterId] to [targetId].
  Future<bool> requestBkash({
    required String groupId,
    required String requesterId,
    required String requesterName,
    required String targetId,
    required String targetName,
    required String groupName,
  }) async {
    try {
      final docId = '${groupId}_${requesterId}_$targetId';
      await _db.collection(AppConstants.colBkashRequests).doc(docId).set({
        'groupId':       groupId,
        'requesterId':   requesterId,
        'requesterName': requesterName,
        'targetId':      targetId,
        'targetName':    targetName,
        'status':        'pending',
        'createdAt':     FieldValue.serverTimestamp(),
      });
      await _notifService.send(
        targetUserId: targetId,
        groupId:      groupId,
        groupName:    groupName,
        type:         AppConstants.notifBkashRequested,
        referenceId:  requesterId,
        message:      '$requesterName is requesting your bKash number',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Target accepts the bKash request — updates status & notifies requester.
  Future<bool> acceptBkashRequest({
    required String groupId,
    required String requesterId,
    required String requesterName,
    required String targetId,
    required String targetName,
    required String groupName,
  }) async {
    try {
      final docId = '${groupId}_${requesterId}_$targetId';
      await _db.collection(AppConstants.colBkashRequests).doc(docId)
          .update({'status': 'accepted'});
      await _notifService.send(
        targetUserId: requesterId,
        groupId:      groupId,
        groupName:    groupName,
        type:         AppConstants.notifBkashAccepted,
        referenceId:  targetId,
        message:      '$targetName shared their bKash number with you',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Target declines the bKash request.
  Future<bool> declineBkashRequest({
    required String groupId,
    required String requesterId,
    required String targetId,
  }) async {
    try {
      final docId = '${groupId}_${requesterId}_$targetId';
      await _db.collection(AppConstants.colBkashRequests).doc(docId)
          .update({'status': 'declined'});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Real-time stream of bKash request status: 'pending'/'accepted'/'declined'/null.
  Stream<String?> bkashStatusStream(
      String groupId, String requesterId, String targetId) {
    final docId = '${groupId}_${requesterId}_$targetId';
    return _db
        .collection(AppConstants.colBkashRequests)
        .doc(docId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          final data = snap.data() as Map<String, dynamic>?;
          return data?['status'] as String?;
        });
  }

  /// Fetches the bKash number of a user from Firestore.
  Future<String?> fetchMemberBkash(String uid) async {
    try {
      final doc  = await _db.collection(AppConstants.colUsers).doc(uid).get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['bkashNumber'] as String?;
    } catch (_) {
      return null;
    }
  }
}
