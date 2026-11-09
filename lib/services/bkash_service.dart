import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bkash_share.dart';
import '../utils/app_constants.dart';
import '../utils/offline.dart';

/// bKash number sharing between two members of a tour.
///
/// One request document per (tour, requester, owner). The owner's number is
/// only ever copied into it when they accept, and the security rules let
/// just those two people read it.
class BkashService {
  BkashService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _request(
    String groupId,
    String requesterId,
    String targetId,
  ) =>
      _db.collection(AppConstants.colBkashRequests).doc('${groupId}_${requesterId}_$targetId');

  /// [requesterId] asks [targetId] for their number.
  Future<void> request({
    required String groupId,
    required String requesterId,
    required String requesterName,
    required String targetId,
    required String targetName,
  }) {
    return saveOrQueue(
      _request(groupId, requesterId, targetId).set({
        'groupId':       groupId,
        'requesterId':   requesterId,
        'requesterName': requesterName,
        'targetId':      targetId,
        'targetName':    targetName,
        'status':        'pending',
        'createdAt':     FieldValue.serverTimestamp(),
      }),
      'request bKash',
    );
  }

  /// The owner accepts, copying their own number into the request.
  Future<void> accept({
    required String groupId,
    required String requesterId,
    required String targetId,
    required String? number,
  }) {
    final trimmed = number?.trim();
    return saveOrQueue(
      _request(groupId, requesterId, targetId).update({
        'status':      'accepted',
        'number':      (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        'respondedAt': FieldValue.serverTimestamp(),
      }),
      'accept bKash',
    );
  }

  /// The owner declines; any number shared earlier is removed.
  Future<void> decline({
    required String groupId,
    required String requesterId,
    required String targetId,
  }) {
    return saveOrQueue(
      _request(groupId, requesterId, targetId).update({
        'status':      'declined',
        'number':      FieldValue.delete(),
        'respondedAt': FieldValue.serverTimestamp(),
      }),
      'decline bKash',
    );
  }

  /// Live state of a request (null if never requested). Once accepted it
  /// carries the shared number.
  Stream<BkashShare?> shareStream(String groupId, String requesterId, String targetId) {
    return _request(groupId, requesterId, targetId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return BkashShare.fromMap(data);
    });
  }
}
