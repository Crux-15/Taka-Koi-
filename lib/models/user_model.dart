import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a registered user in the app.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String avatarUrl;
  final String? bkashNumber;
  final String? activeGroupId;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.avatarUrl,
    this.bkashNumber,
    this.activeGroupId,
    required this.createdAt,
  });

  // ── Serialisation ─────────────────────────────────────────────────────────
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid:           map['uid']           as String? ?? '',
      name:          map['name']          as String? ?? '',
      email:         map['email']         as String? ?? '',
      avatarUrl:     map['avatarUrl']     as String? ?? '',
      bkashNumber:   map['bkashNumber']   as String?,
      activeGroupId: map['activeGroupId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid':           uid,
      'name':          name,
      'email':         email,
      'avatarUrl':     avatarUrl,
      'bkashNumber':   bkashNumber,
      'activeGroupId': activeGroupId,
      'createdAt':     Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? avatarUrl,
    String? bkashNumber,
    String? activeGroupId,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid:           uid           ?? this.uid,
      name:          name          ?? this.name,
      email:         email         ?? this.email,
      avatarUrl:     avatarUrl     ?? this.avatarUrl,
      bkashNumber:   bkashNumber   ?? this.bkashNumber,
      activeGroupId: activeGroupId ?? this.activeGroupId,
      createdAt:     createdAt     ?? this.createdAt,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, name: $name, email: $email)';
}
