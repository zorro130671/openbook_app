import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMetadataHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mark messages as read by resetting unread count and updating lastReadTimestamp
  Future<void> markMessagesRead(String chatId, String userId) async {
    final docRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('metadata')
        .doc(userId);

    await docRef.set({
      'unreadCount': 0,
      'lastReadTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Increment unread count for all participants except the sender
  Future<void> incrementUnreadForOthers(
    String chatId,
    List<String> participantIds,
    String senderId,
  ) async {
    final batch = _firestore.batch();

    for (final userId in participantIds) {
      if (userId == senderId) continue;

      final docRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('metadata')
          .doc(userId);

      batch.set(docRef, {
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Set or update favorite flag for user in a chat
  Future<void> setFavorite(
    String chatId,
    String userId,
    bool isFavorite,
  ) async {
    final docRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('metadata')
        .doc(userId);

    await docRef.set({'isFavorite': isFavorite}, SetOptions(merge: true));
  }

  /// Stream metadata for a user in a chat (to listen for changes)
  Stream<DocumentSnapshot> getMetadataStream(String chatId, String userId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('metadata')
        .doc(userId)
        .snapshots();
  }
}
