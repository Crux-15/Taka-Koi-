import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../utils/app_constants.dart';

/// Handles writing and reading in-app notifications from Firestore.
class NotificationService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final Uuid              _uuid = const Uuid();

  CollectionReference get _notifs =>
      _db.collection(AppConstants.colNotifications);

  // ── Write ─────────────────────────────────────────────────────────────────
  Future<void> send({
    required String targetUserId,
    required String groupId,
    required String type,
    required String referenceId,
    required String message,
    String groupName = '',
  }) async {
    final id = _uuid.v4();
    await _notifs.doc(id).set({
      'targetUserId': targetUserId,
      'groupId':      groupId,
      'groupName':    groupName,
      'type':         type,
      'referenceId':  referenceId,
      'message':      message,
      'isRead':       false,
      'createdAt':    Timestamp.now(),
    });
  }

  /// Convenience: send to multiple users at once.
  Future<void> sendToMany({
    required List<String> targetUserIds,
    required String groupId,
    required String type,
    required String referenceId,
    required String message,
    String groupName = '',
  }) async {
    final batch = _db.batch();
    for (final uid in targetUserIds) {
      final ref = _notifs.doc(_uuid.v4());
      batch.set(ref, {
        'targetUserId': uid,
        'groupId':      groupId,
        'groupName':    groupName,
        'type':         type,
        'referenceId':  referenceId,
        'message':      message,
        'isRead':       false,
        'createdAt':    Timestamp.now(),
      });
    }
    await batch.commit();
  }

  // ── Read ──────────────────────────────────────────────────────────────────
  /// Real-time stream of all notifications for the current user, newest first.
  /// Single-field query only (no composite index needed); sorts in Dart.
  Stream<List<NotificationModel>> notificationsStream(String userId) {
    return _notifs
        .where('targetUserId', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final list = s.docs.map(NotificationModel.fromDoc).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Count of unread notifications (for badge).
  /// Uses single-field query only (no composite index needed).
  Stream<int> unreadCountStream(String userId) {
    return _notifs
        .where('targetUserId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs
            .map(NotificationModel.fromDoc)
            .where((n) => !n.isRead)
            .length);
  }

  // ── Mark Read ─────────────────────────────────────────────────────────────
  Future<void> markAsRead(String notificationId) async {
    await _notifs.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snap = await _notifs
        .where('targetUserId', isEqualTo: userId)
        .where('isRead',       isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
