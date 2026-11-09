import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tour_expense_tracker/models/bkash_share.dart';
import 'package:tour_expense_tracker/models/group_model.dart';

GroupModel _group({required List<String> members, required List<String> memberIds}) {
  final now = DateTime(2026);
  return GroupModel(
    groupId:            'g',
    name:               'Trip',
    adminId:            members.first,
    creatorId:          members.first,
    currency:           'BDT',
    currencySymbol:     '৳',
    status:             'active',
    groupCode:          'ABC234',
    groupCodeExpiresAt: now,
    lastActivityAt:     now,
    createdAt:          now,
    members: {
      for (final uid in members)
        uid: GroupMember(userId: uid, name: uid, avatarUrl: '', joinedAt: now),
    },
    memberIds: memberIds,
  );
}

void main() {
  group('GroupModel.memberIds', () {
    test('in sync when it lists exactly the members', () {
      expect(_group(members: ['a', 'b'], memberIds: ['b', 'a']).memberIdsInSync, isTrue);
    });

    test('out of sync for older groups without it, or when it drifts', () {
      expect(_group(members: ['a', 'b'], memberIds: const []).memberIdsInSync, isFalse);
      expect(_group(members: ['a', 'b'], memberIds: ['a']).memberIdsInSync, isFalse);
      expect(_group(members: ['a'], memberIds: ['a', 'x']).memberIdsInSync, isFalse);
    });

    test('is always written from the member map', () {
      final map = _group(members: ['a', 'b'], memberIds: const []).toMap();
      expect(map['memberIds'], ['a', 'b']);
      expect(map['groupCodeExpiresAt'], isA<Timestamp>());
    });
  });

  group('BkashShare', () {
    test('an accepted request carries the shared number', () {
      final share = BkashShare.fromMap({'status': 'accepted', 'number': '01700000000'});
      expect(share.isAccepted, isTrue);
      expect(share.number, '01700000000');
    });

    test('accepted without a number set is still accepted', () {
      final share = BkashShare.fromMap({'status': 'accepted', 'number': null});
      expect(share.isAccepted, isTrue);
      expect(share.legacy, isFalse);
      expect(share.number, isNull);
    });

    test('an acceptance from the old app has no number field, so it can be asked again', () {
      final share = BkashShare.fromMap({'status': 'accepted'});
      expect(share.legacy, isTrue);
      expect(share.isAccepted, isFalse);
    });

    test('pending and declined', () {
      expect(BkashShare.fromMap({'status': 'pending'}).isPending, isTrue);
      expect(BkashShare.fromMap({'status': 'declined'}).isAccepted, isFalse);
    });
  });
}
