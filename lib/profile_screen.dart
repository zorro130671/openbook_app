import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel currentUser;
  const ProfileScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 48,
            backgroundImage: currentUser.avatarUrl.startsWith('assets/')
                ? AssetImage(currentUser.avatarUrl)
                : NetworkImage(currentUser.avatarUrl) as ImageProvider,
          ),
          const SizedBox(height: 16),
          Text(
            currentUser.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            currentUser.email,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Status'),
            subtitle: Text(currentUser.statusMessage ?? '—'),
          ),
          ListTile(
            leading: const Icon(Icons.circle),
            title: const Text('Online'),
            subtitle: Text('${currentUser.isOnline == true ? "Yes" : "No"}'),
          ),
        ],
      ),
    );
  }
}
