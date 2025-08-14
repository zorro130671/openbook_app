import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ContactsScreen extends StatelessWidget {
  final List<UserModel> contacts;
  const ContactsScreen({super.key, required this.contacts});

  ImageProvider<Object> _img(String url) =>
      url.startsWith('assets/') ? AssetImage(url) : NetworkImage(url);

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
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: _img(u.avatarUrl),
                      ),
                      // Online dot (no Positioned => use Align so we never trigger ParentData issues)
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
                onTap: () =>
                    Navigator.pop(context, u), // return selection if needed
              ),
              const Divider(height: 0),
            ],
          );
        },
      ),
    );
  }
}
