import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // for Timestamp

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String avatarUrl;

  // Presence / status
  final String? statusMessage;
  final bool? isOnline;
  final DateTime? lastSeen;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    this.statusMessage,
    this.isOnline,
    this.lastSeen,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) {
    String _s(dynamic v, [String d = '']) =>
        (v is String && v.isNotEmpty) ? v : d;
    bool? _b(dynamic v) => (v is bool) ? v : null;

    return UserModel(
      uid: _s(m['uid'], ''), // fallback empty string
      displayName: _s(m['displayName'], 'Unknown'), // fallback "Unknown"
      email: _s(m['email'], ''), // fallback empty
      avatarUrl: _s(
        m['avatarUrl'],
        'assets/images/avatars/zah_avatar.png', // fallback asset
      ),
      statusMessage:
          (m['statusMessage'] is String &&
              (m['statusMessage'] as String).isNotEmpty)
          ? m['statusMessage'] as String
          : null,
      isOnline: _b(m['isOnline']),
      lastSeen: m['lastSeen'] is Timestamp
          ? (m['lastSeen'] as Timestamp).toDate()
          : (m['lastSeen'] is String
                ? DateTime.tryParse(m['lastSeen'] as String)
                : null),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'avatarUrl': avatarUrl,
    if (statusMessage != null) 'statusMessage': statusMessage,
    if (isOnline != null) 'isOnline': isOnline,
    if (lastSeen != null) 'lastSeen': lastSeen,
  };
}
