import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as dev;

// Skip these users so only the new 20 get fixed
const skipIds = {
  'NhY1NzNu0FgCPCvboeHSPqoy7Ng2', // Zah Martin
  'wv2OJVWg8fPo1qZTN483QGqyt132', // Sumitra Nathan
  'XenOj61VJRc7rMmrPykMNIMhr', // Liam Wong
};

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Future<void> fixAvatarsOnce() async {
  final fs = FirebaseFirestore.instance;
  final st = FirebaseStorage.instance;

  Future<void> processFolder(String folder) async {
    final result = await st.ref(folder).listAll(); // e.g., 'avatars/female'
    for (final ref in result.items) {
      final file = ref.name; // e.g., amelia_collins_f.png
      final base = file.split('.').first; // amelia_collins_f
      final parts = base.split('_'); // [amelia, collins, f]

      if (parts.length < 2) {
        dev.log('skip: $file');
        continue;
      }

      // Drop trailing gender letter if present
      if (parts.last.length == 1 && (parts.last == 'm' || parts.last == 'f')) {
        parts.removeLast();
      }

      // Build display name from remaining parts
      final displayName = parts.map((p) => _cap(p.toLowerCase())).join(' ');

      // Find user(s) by displayName
      final q = await fs
          .collection('users')
          .where('displayName', isEqualTo: displayName)
          .get();

      if (q.docs.isEmpty) {
        dev.log('no user for "$displayName" from $file');
        continue;
      }

      final storagePath = '$folder/$file';
      final url = await ref.getDownloadURL();

      for (final doc in q.docs) {
        if (skipIds.contains(doc.id)) {
          dev.log('skipped ${doc.id} ($displayName)');
          continue;
        }
        await doc.reference.update({
          'avatarPath': storagePath,
          'avatarUrl': url,
          'photoUrl': url,
          'avatarFixedAt': FieldValue.serverTimestamp(),
        });
        dev.log('updated ${doc.id} ($displayName) <- $file');
      }
    }
  }

  await processFolder('avatars/female');
  await processFolder('avatars/male');

  dev.log('fixAvatarsOnce DONE');
}
