import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../utils/app_constants.dart';
import '../utils/offline.dart';

/// Handles writing and reading in-app notifications from Firestore.
class NotificationService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final Uuid              _uuid = const Uuid();

  CollectionReference get _notifs =>
      _db.collection(AppConstants.colNotifications);

  /// Who sent it. Security rules require this to be the signed-in user, and
  /// only allow notifying people in a tour you're in.
  String get _senderId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Write ─────────────────────────────────────────────────────────────────
  /// Returns false if it's still waiting to sync (offline); it's delivered
  /// once the connection is back.
  Future<bool> send({
    required String targetUserId,
    required String groupId,
    required String type,
    required String referenceId,
    required String message,
    String groupName = '',
  }) async {
    final id = _uuid.v4();
    return saveOrQueue(_notifs.doc(id).set({
      'senderId':     _senderId,
      'targetUserId': targetUserId,
      'groupId':      groupId,
      'groupName':    groupName,
      'type':         type,
      'referenceId':  referenceId,
      'message':      message,
      'isRead':       false,
      'createdAt':    Timestamp.now(),
    }), 'send notification');
  }

  /// Convenience: send to multiple users at once.
  Future<bool> sendToMany({
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
        'senderId':     _senderId,
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
    return saveOrQueue(batch.commit(), 'send notifications');
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

  // ── Mark Read ─────────────────────────────────────────────────────────────
  Future<void> markAsRead(String notificationId) async {
    await saveOrQueue(_notifs.doc(notificationId).update({'isRead': true}), 'mark read');
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
    await saveOrQueue(batch.commit(), 'mark all read');
  }
}
