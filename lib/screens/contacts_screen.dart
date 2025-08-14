// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ContactsScreen extends StatelessWidget {
  final List<UserModel> contacts;
  const ContactsScreen({super.key, required this.contacts});

  // ---- Avatar helpers -------------------------------------------------------

  // Use the canonical bucket for REST download URLs (works on web & mobile)
  static const String _bucket = 'open-book-16zt1k.appspot.com';

  String _toDownloadUrl(String storagePath) {
    final encoded = Uri.encodeComponent(storagePath);
    return 'https://firebasestorage.googleapis.com/v0/b/$_bucket/o/$encoded?alt=media';
  }

  ImageProvider<Object>? _avatarProvider(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null; // let initials show
    if (v.startsWith('assets/')) return AssetImage(v);
    if (v.startsWith('http')) return NetworkImage(v);
    // Otherwise assume it's a Firebase Storage path like "avatars/sumitra.png"
    return NetworkImage(_toDownloadUrl(v));
  }

  String _initialOf(String s) => (s.isNotEmpty ? s[0] : '?').toUpperCase();

  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: contacts.length,
        itemBuilder: (_, i) {
          final u = contacts[i];

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 4,
                ),
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // CircleAvatar with initials fallback until the image loads
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        child: Text(
                          _initialOf(u.displayName),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        foregroundImage: _avatarProvider(u.avatarUrl),
                      ),
                      // Online dot (use Align to avoid ParentData exceptions)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: (u.isOnline == true)
                                ? Colors.green
                                : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                title: Text(
                  u.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  (u.statusMessage?.isNotEmpty == true)
                      ? u.statusMessage!
                      : u.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(Icons.message, color: cs.primary),
                onTap: () => Navigator.pop(context, u), // return selection
              ),
              const Divider(height: 0),
            ],
          );
        },
      ),
    );
  }
}
