import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bkash_share.dart';
import '../models/group_model.dart';
import '../services/bkash_service.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_exception.dart';
import '../utils/app_log.dart';
import '../utils/offline.dart';

enum GroupStatus { initial, loading, loaded, error }

/// Controller for group management operations.
class GroupController extends ChangeNotifier {
  /// Services can be swapped for fakes in tests.
  GroupController({
    GroupService?        groupService,
    NotificationService? notificationService,
    BkashService?        bkashService,
  })  : _groupService = groupService ?? GroupService(),
        _notifService = notificationService ?? NotificationService(),
        _bkashService = bkashService ?? BkashService();

  final GroupService        _groupService;
  final NotificationService _notifService;
  final BkashService        _bkashService;

  GroupStatus  _status       = GroupStatus.initial;
  GroupModel?  _activeGroup;
  String?      _errorMessage;
  List<GroupModel> _history  = [];
  StreamSubscription<GroupModel?>? _groupSub;
  bool _refreshingCode = false;
  String? _currentUserId; // stored so stream can detect when THIS user is removed
  String? _autoEndTried;   // group we already tried to auto-end this session
  String? _backfilled;     // group whose memberIds we already filled in

  GroupStatus       get status          => _status;
  GroupModel?       get activeGroup     => _activeGroup;
  String?           get errorMessage    => _errorMessage;
  List<GroupModel>  get history         => _history;
  bool get isLoading        => _status == GroupStatus.loading;
  bool get hasActiveGroup   => _activeGroup != null && _activeGroup!.isActive;
  bool get isRefreshingCode => _refreshingCode;

  /// Tests and screenshots only: show [group] as the active tour without
  /// listening to the database.
  @visibleForTesting
  void debugSetActiveGroup(GroupModel group, {String? currentUserId}) {
    _activeGroup   = group;
    _currentUserId = currentUserId ?? _currentUserId;
    _status        = GroupStatus.loaded;
    notifyListeners();
  }

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
        _handleRemovedFromGroup(groupId);
        return;
      }

      // If the group is still active but THIS user is no longer in members,
      // the admin approved their leave request on another device.
      if (group.isActive &&
          _currentUserId != null &&
          !group.members.containsKey(_currentUserId)) {
        _handleRemovedFromGroup(groupId);
        return;
      }

      _activeGroup = group;
      _status      = GroupStatus.loaded;

      // If the group just became inactive (admin ended it on another device),
      // proactively load history so Past Tours shows immediately on redirect.
      if (!group.isActive && _currentUserId != null) {
        loadHistory(_currentUserId!); // fire-and-forget; notifyListeners handles redirect
        _clearOwnActiveGroup(groupId);
      }

      notifyListeners();
      if (group.isActive) {
        _backfillMemberIds(group);
        _checkInactivity(group);
      }
    }, onError: (Object e, StackTrace s) {
      // Once you're removed from a tour the rules stop you reading it, so the
      // stream fails instead of showing you missing from the member list.
      if (e is FirebaseException && e.code == 'permission-denied') {
        _handleRemovedFromGroup(groupId);
      } else {
        logError('group stream', e, s);
      }
    });
  }

  /// Older tours don't have the memberIds list that tour history and the
  /// security rules rely on; any member's app fills it in.
  void _backfillMemberIds(GroupModel group) {
    if (group.memberIdsInSync || _backfilled == group.groupId) return;
    _backfilled = group.groupId;
    inBackground(
      _groupService.backfillMemberIds(group.groupId, group.members.keys.toList()),
      'backfill memberIds',
    );
  }

  /// Each user clears their own active tour; nobody can edit anyone else's profile.
  void _clearOwnActiveGroup(String groupId) {
    final uid = _currentUserId;
    if (uid == null) return;
    inBackground(
      _groupService.clearActiveGroup(userId: uid, groupId: groupId),
      'clear own active tour',
    );
  }

  /// Called when the current user is kicked out or their leave is approved.
  /// Clears all group state and triggers a router redirect to the group hub.
  Future<void> _handleRemovedFromGroup(String groupId) async {
    _groupSub?.cancel();
    _groupSub = null;
    _activeGroup = null;
    _status = GroupStatus.initial;
    _clearOwnActiveGroup(groupId);
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

  /// Ends an idle tour. The server only accepts this once it agrees there's
  /// been no activity for 4 days, so a phone with a wrong clock or stale data
  /// can't end a tour early. Tried at most once per tour per session.
  void _checkInactivity(GroupModel group) {
    final daysSinceLast = DateTime.now().difference(group.lastActivityAt).inDays;
    if (daysSinceLast < AppConstants.inactivityDays) return;
    if (_autoEndTried == group.groupId) return;
    _autoEndTried = group.groupId;
    _autoEnd(group);
  }

  Future<void> _autoEnd(GroupModel group) async {
    try {
      final ended = await _groupService.autoEndIfIdle(group.groupId);
      if (!ended) return;
    } catch (e, s) {
      // Offline, or the server says it isn't idle yet. Nothing changed.
      logError('auto-end tour', e, s);
      return;
    }
    // Everyone's stream sees the tour end and moves them out of it.
    inBackground(
      _notifService.sendToMany(
        targetUserIds: group.members.keys.toList(),
        groupId:       group.groupId,
        groupName:     group.name,
        type:          AppConstants.notifGroupAutoDeactivated,
        referenceId:   group.groupId,
        message:       'Your tour "${group.name}" was automatically ended after '
            '${AppConstants.inactivityDays} days without activity.',
      ),
      'notify tour auto-ended',
    );
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
      _setError(friendlyError(e, 'Failed to create group. Please try again.'));
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
        _setError('That code doesn\'t work. It may be mistyped or expired: ask for a new one.');
        return false;
      }
      // Start listening to the group stream so state is live
      listenToGroup(group.groupId, currentUserId: userId);
      _status = GroupStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(friendlyError(e, 'Failed to join group. Please try again.'));
      return false;
    }
  }


  // ── Admin: Refresh Code ───────────────────────────────────────────────────
  Future<void> refreshGroupCode() async {
    if (_activeGroup == null || _refreshingCode) return;
    _refreshingCode = true;
    notifyListeners();
    try {
      await _groupService.refreshGroupCode(
        _activeGroup!.groupId,
        oldCode: _activeGroup!.groupCode,
      );
      // The Firestore stream will auto-update _activeGroup with the new code
    } catch (e) {
      _errorMessage = friendlyError(e, "Couldn't refresh the code. Try again.");
    } finally {
      _refreshingCode = false;
      notifyListeners();
    }
  }

  // ── Admin: Remove Member ──────────────────────────────────────────────────
  /// Returns false (with [errorMessage] set) if it didn't work.
  Future<bool> removeMember(String memberId) async {
    if (_activeGroup == null) return false;
    final member = _activeGroup!.members[memberId];
    if (member == null) return false;
    if (member.hasApprovedExpense) {
      _errorMessage = '${member.name} is part of an approved expense, so they can\'t be '
          'removed. They can ask to leave instead.';
      notifyListeners();
      return false;
    }
    try {
      await _groupService.removeMember(groupId: _activeGroup!.groupId, memberId: memberId);
      return true;
    } catch (e, s) {
      logError('remove member', e, s);
      _errorMessage = friendlyError(e, 'Couldn\'t remove that member. Try again.');
      notifyListeners();
      return false;
    }
  }

  // ── Admin: Transfer Admin Role ────────────────────────────────────────────
  /// Returns false (with [errorMessage] set) if it didn't work.
  Future<bool> transferAdmin(String newAdminId) async {
    final group = _activeGroup;
    if (group == null) return false;
    try {
      await _groupService.transferAdmin(groupId: group.groupId, newAdminId: newAdminId);
    } catch (e, s) {
      logError('transfer admin', e, s);
      _errorMessage = friendlyError(e, 'Couldn\'t hand over the admin role. Try again.');
      notifyListeners();
      return false;
    }
    inBackground(
      _notifService.send(
        targetUserId: newAdminId,
        groupId:      group.groupId,
        type:         AppConstants.notifAdminTransferRequired,
        referenceId:  group.groupId,
        message:      'You are now the admin of ${group.name}.',
      ),
      'notify new admin',
    );
    return true;
  }

  // ── Deactivate Group (admin) ──────────────────────────────────────────────
  /// The admin ends the tour. Returns false (with [errorMessage] set) if it
  /// didn't work. Idle tours are ended by [_autoEnd] instead.
  Future<bool> deactivateGroup({
    required String groupId,
    required List<String> memberIds,
    String groupName = '',
  }) async {
    try {
      await _groupService.deactivateGroup(groupId: groupId);
    } catch (e, s) {
      logError('end tour', e, s);
      _errorMessage = friendlyError(e, 'Couldn\'t end the tour. Try again.');
      notifyListeners();
      return false;
    }
    // Notify ALL members that the group ended (their devices also react via the stream)
    inBackground(
      _notifService.sendToMany(
        targetUserIds: memberIds,
        groupId:       groupId,
        groupName:     groupName,
        type:          AppConstants.notifGroupEnded,
        referenceId:   groupId,
        message:       'Your tour "$groupName" has been ended by the admin.',
      ),
      'notify tour ended',
    );
    _clearOwnActiveGroup(groupId);
    // Clear persisted group ID so re-opening doesn't try to restore a dead group
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeGroupId');

    // Proactively load history for the admin so Past Tours shows immediately
    if (_currentUserId != null) {
      await loadHistory(_currentUserId!);
    }
    _activeGroup = null;
    notifyListeners();
    return true;
  }

  // ── Leave Group (member-initiated, requires admin approval) ───────────────
  Future<bool> requestLeave({required String userId, required String userName}) async {
    if (_activeGroup == null) return false;
    _errorMessage = null;
    try {
      final open = await _groupService.openItemsFor(_activeGroup!.groupId, userId);
      final blocker = _blocker(open, 'you', 'Settle up first, then ask to leave.');
      if (blocker != null) {
        _errorMessage = blocker;
        notifyListeners();
        return false;
      }
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
        message:      '$userName wants to leave "${_activeGroup!.name}". Tap to review.',
      );
      return true;
    } catch (e, s) {
      logError('request leave', e, s);
      _errorMessage = friendlyError(e, 'Couldn\'t send the request. Try again.');
      return false;
    }
  }

  Future<bool> approveLeave({required String memberId, required String memberName}) async {
    if (_activeGroup == null) return false;
    final group = _activeGroup!;
    _errorMessage = null;
    try {
      final open = await _groupService.openItemsFor(group.groupId, memberId);
      final blocker = _blocker(open, memberName, 'Ask them to settle up first.');
      if (blocker != null) {
        _errorMessage = blocker;
        notifyListeners();
        return false;
      }
      await _groupService.approveLeave(groupId: group.groupId, memberId: memberId);
    } catch (e, s) {
      logError('approve leave', e, s);
      _errorMessage = friendlyError(e, 'Couldn\'t approve it. Try again.');
      return false;
    }
    inBackground(
      _notifService.send(
        targetUserId: memberId,
        groupId:      group.groupId,
        type:         AppConstants.notifLeaveApproved,
        referenceId:  group.groupId,
        message:      'Your request to leave "${group.name}" has been approved.',
      ),
      'notify leave approved',
    );
    return true;
  }

  Future<bool> rejectLeave({required String memberId, required String memberName}) async {
    if (_activeGroup == null) return false;
    final group = _activeGroup!;
    try {
      await _groupService.rejectLeave(groupId: group.groupId, memberId: memberId);
    } catch (e, s) {
      logError('reject leave', e, s);
      return false;
    }
    inBackground(
      _notifService.send(
        targetUserId: memberId,
        groupId:      group.groupId,
        type:         AppConstants.notifLeaveRejected,
        referenceId:  group.groupId,
        message:      'Your request to leave "${group.name}" was rejected by the admin.',
      ),
      'notify leave rejected',
    );
    return true;
  }

  Stream<List<Map<String, dynamic>>> leaveRequestsStream() {
    if (_activeGroup == null) return const Stream.empty();
    return _groupService.leaveRequestsStream(_activeGroup!.groupId);
  }

  // ── Remove from History ───────────────────────────────────────────────────
  /// Returns false (with [errorMessage] set) if it didn't work.
  Future<bool> removeFromHistory({required String groupId, required String userId}) async {
    _errorMessage = null;
    try {
      final open = await _groupService.openItemsFor(groupId, userId);
      final blocker = _blocker(open, 'you', 'Settle up before removing it.');
      if (blocker != null) {
        _errorMessage = blocker;
        notifyListeners();
        return false;
      }
      await _groupService.removeFromHistory(groupId: groupId, userId: userId);
    } catch (e, s) {
      logError('remove from history', e, s);
      _errorMessage = friendlyError(e, 'Couldn\'t remove that tour. Try again.');
      notifyListeners();
      return false;
    }
    // Remove locally so the list updates instantly without re-fetching
    _history.removeWhere((g) => g.groupId == groupId);
    notifyListeners();
    return true;
  }

  /// Unsettled debts in the tour, for the "end tour" warning (0 if unknown).
  Future<int> openDebtCount(String groupId) async {
    try {
      return await _groupService.openDebtCount(groupId);
    } catch (e, s) {
      logError('count open debts', e, s);
      return 0;
    }
  }

  /// A plain explanation of why someone can't leave yet, or null if they can.
  static String? _blocker(({int owes, int owed, int pending}) open, String who, String advice) {
    final you  = who == 'you';
    final name = you ? 'You' : who;
    if (open.owes > 0) return '$name still ${you ? 'owe' : 'owes'} money in this tour. $advice';
    if (open.owed > 0) return '$name ${you ? 'are' : 'is'} still owed money in this tour. $advice';
    if (open.pending > 0) {
      return 'There ${open.pending == 1 ? 'is an expense' : 'are expenses'} waiting on '
          '${you ? 'you' : who}. Approve, reject or delete ${open.pending == 1 ? 'it' : 'them'} first.';
    }
    return null;
  }

  // ── Load History ──────────────────────────────────────────────────────────
  Future<void> loadHistory(String userId) async {
    try {
      _history = await _groupService.fetchUserGroupHistory(userId);
      notifyListeners();
    } catch (e, s) {
      // Keeps showing the last list it had.
      logError('load tour history', e, s);
    }
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
      await _bkashService.request(
        groupId:       groupId,
        requesterId:   requesterId,
        requesterName: requesterName,
        targetId:      targetId,
        targetName:    targetName,
      );
    } catch (e, s) {
      logError('request bKash', e, s);
      return false;
    }
    inBackground(
      _notifService.send(
        targetUserId: targetId,
        groupId:      groupId,
        groupName:    groupName,
        type:         AppConstants.notifBkashRequested,
        referenceId:  requesterId,
        message:      '$requesterName is requesting your bKash number',
      ),
      'notify bKash request',
    );
    return true;
  }

  /// Target accepts the bKash request: copies their own number into the
  /// request (the only place the requester can read it) and notifies them.
  Future<bool> acceptBkashRequest({
    required String groupId,
    required String requesterId,
    required String requesterName,
    required String targetId,
    required String targetName,
    required String groupName,
    required String? myBkashNumber,
  }) async {
    try {
      await _bkashService.accept(
        groupId:     groupId,
        requesterId: requesterId,
        targetId:    targetId,
        number:      myBkashNumber,
      );
    } catch (e, s) {
      logError('accept bKash', e, s);
      return false;
    }
    inBackground(
      _notifService.send(
        targetUserId: requesterId,
        groupId:      groupId,
        groupName:    groupName,
        type:         AppConstants.notifBkashAccepted,
        referenceId:  targetId,
        message:      '$targetName shared their bKash number with you',
      ),
      'notify bKash accepted',
    );
    return true;
  }

  /// Target declines the bKash request.
  Future<bool> declineBkashRequest({
    required String groupId,
    required String requesterId,
    required String targetId,
  }) async {
    try {
      await _bkashService.decline(
        groupId:     groupId,
        requesterId: requesterId,
        targetId:    targetId,
      );
      return true;
    } catch (e, s) {
      logError('decline bKash', e, s);
      return false;
    }
  }

  /// Real-time state of a bKash request (null if never requested). Once
  /// accepted it carries the shared number.
  Stream<BkashShare?> bkashShareStream(String groupId, String requesterId, String targetId) =>
      _bkashService.shareStream(groupId, requesterId, targetId);
}
