// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  /// Ensure the current user's document exists and contains all required schema keys.
  /// - If the doc doesn't exist: create with full defaults.
  /// - If it exists: patch only the missing keys (merge).
  static Future<void> ensureUserDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = _db.collection('users').doc(user.uid);
    final snap = await docRef.get();
    final now = FieldValue.serverTimestamp();

    if (!snap.exists) {
      await docRef.set({
        // Identity
        'uid': user.uid,
        'displayName': user.displayName ?? '',
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phoneNumber': user.phoneNumber ?? '',
        'phone': user.phoneNumber ?? '',
        'photoURL': user.photoURL,
        'avatarUrl': user.photoURL,

        // Profile
        'gender': null,
        'bio': '',
        'status': 'online',
        'statusMessage': 'Available',
        'isOnline': true,
        'lastSeen': now,

        // Social / counters / prefs
        'followersCount': 0,
        'followingCount': 0,
        'postsCount': 0,
        'messagesCount': 0,
        'isVerified': false,
        'isDeleted': false,
        'muteStatus': false,
        'notificationsEnabled': true,
        'readReceipts': true,
        'themePreference': 'light', // or 'system', your call
        'socialLinks': <String>[],
        'website': '',

        // Timestamps
        'createdAt': now,
        'updatedAt': now,
      });
      return;
    }

    // Doc exists — add only missing keys.
    final data = snap.data() as Map<String, dynamic>;
    final patch = <String, dynamic>{};
    void addIfMissing(String key, dynamic value) {
      if (!data.containsKey(key) || data[key] == null) {
        patch[key] = value;
      }
    }

    // Identity & mirroring
    addIfMissing('uid', user.uid);
    addIfMissing('displayName', (data['name'] ?? user.displayName ?? ''));
    addIfMissing('name', (data['displayName'] ?? user.displayName ?? ''));
    addIfMissing('email', data['email'] ?? user.email ?? '');
    addIfMissing('phoneNumber', data['phone'] ?? user.phoneNumber ?? '');
    addIfMissing('phone', data['phoneNumber'] ?? user.phoneNumber ?? '');

    // Keep avatarUrl / photoURL mirrored if either is missing
    if (!data.containsKey('photoURL') && data.containsKey('avatarUrl')) {
      patch['photoURL'] = data['avatarUrl'];
    }
    if (!data.containsKey('avatarUrl') && data.containsKey('photoURL')) {
      patch['avatarUrl'] = data['photoURL'];
    }

    // Profile
    addIfMissing('gender', data['gender']);
    addIfMissing('bio', data['bio'] ?? data['statusMessage'] ?? '');
    addIfMissing('status', data['status'] ?? 'online');
    // Derive isOnline from status if missing
    if (!data.containsKey('isOnline')) {
      final st = (data['status'] ?? 'online').toString();
      patch['isOnline'] = st == 'online';
    }
    addIfMissing('statusMessage', data['statusMessage'] ?? 'Available');
    addIfMissing('lastSeen', now);

    // Social / counters / prefs
    addIfMissing('followersCount', 0);
    addIfMissing('followingCount', 0);
    addIfMissing('postsCount', 0);
    addIfMissing('messagesCount', 0);
    addIfMissing('isVerified', false);
    addIfMissing('isDeleted', false);
    addIfMissing('muteStatus', false);
    addIfMissing('notificationsEnabled', true);
    addIfMissing('readReceipts', true);
    addIfMissing('themePreference', 'light'); // or 'system'
    addIfMissing('socialLinks', <String>[]);
    addIfMissing('website', '');

    if (patch.isNotEmpty) {
      patch['updatedAt'] = now;
      await docRef.set(patch, SetOptions(merge: true));
    }
  }

  /// Merge-update with derived fields and updatedAt.
  static Future<void> updateUserFields(Map<String, dynamic> fields) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = _db.collection('users').doc(user.uid);

    // Keep legacy/derived fields in sync (status -> isOnline, avatarUrl/photoURL).
    if (fields.containsKey('status')) {
      final st = (fields['status'] ?? '').toString();
      fields['isOnline'] = st == 'online';
      fields['lastSeen'] = FieldValue.serverTimestamp();
    }
    if (fields.containsKey('avatarUrl') && !fields.containsKey('photoURL')) {
      fields['photoURL'] = fields['avatarUrl'];
    }
    if (fields.containsKey('photoURL') && !fields.containsKey('avatarUrl')) {
      fields['avatarUrl'] = fields['photoURL'];
    }

    fields['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(fields, SetOptions(merge: true));
  }
}
