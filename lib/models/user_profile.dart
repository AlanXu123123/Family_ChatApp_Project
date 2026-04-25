import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final DateTime joinedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'joinedAt': FieldValue.serverTimestamp(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    uid: map['uid'] ?? '',
    email: map['email'] ?? '',
    displayName: map['displayName'] ?? '',
    avatarUrl: map['avatarUrl'],
    joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
