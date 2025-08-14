import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel currentUser;
  const SettingsScreen({super.key, required this.currentUser});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loadingAvatars = false;
  List<_AvatarItem> _male = [];
  List<_AvatarItem> _female = [];

  User? get _authUser => FirebaseAuth.instance.currentUser;

  Future<void> _reloadAuthUser() async {
    await _authUser?.reload();
  }

  Future<void> _loadAvatars() async {
    if (_loadingAvatars) return;
    setState(() => _loadingAvatars = true);
    try {
      final storage = FirebaseStorage.instance;
      final maleRef = storage.ref('avatars/male');
      final femaleRef = storage.ref('avatars/female');

      // List both folders in parallel
      final results = await Future.wait([
        maleRef.listAll(),
        femaleRef.listAll(),
      ]);
      final maleList = results[0];
      final femaleList = results[1];

      Future<List<_AvatarItem>> buildItems(ListResult lr, String folder) async {
        // Fetch download URLs in parallel
        final futures = lr.items.map((item) async {
          final url = await item.getDownloadURL();
          return _AvatarItem(
            name: item.name,
            path: '$folder/${item.name}',
            url: url,
          );
        }).toList();
        return await Future.wait(futures);
      }

      final male = await buildItems(maleList, 'avatars/male');
      final female = await buildItems(femaleList, 'avatars/female');

      if (!mounted) return;
      setState(() {
        _male = male;
        _female = female;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load avatars: $e')));
    } finally {
      if (mounted) setState(() => _loadingAvatars = false);
    }
  }

  Future<void> _chooseAvatar() async {
    await _loadAvatars();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 42,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Text(
                  'Choose an Avatar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_loadingAvatars) const LinearProgressIndicator(),
                if (!_loadingAvatars) ...[
                  _section('Female'),
                  _avatarGrid(sheetCtx, _female),
                  const SizedBox(height: 12),
                  _section('Male'),
                  _avatarGrid(sheetCtx, _male),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _section(String title) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _avatarGrid(BuildContext sheetCtx, List<_AvatarItem> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'No images found',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            Navigator.of(sheetCtx).pop(); // ✅ close the bottom sheet
            await _applyAvatar(it); // then apply avatar
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(it.url, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Future<void> _applyAvatar(_AvatarItem item) async {
    try {
      // Cache-bust so browsers don't serve a stale image
      final ts = DateTime.now().millisecondsSinceEpoch;
      final busted = item.url.contains('?')
          ? '${item.url}&v=$ts'
          : '${item.url}?v=$ts';

      await _authUser?.updatePhotoURL(busted);
      await _reloadAuthUser();

      if (!mounted) return;
      setState(() {}); // refresh header immediately

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Avatar updated: ${item.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to set avatar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (widget.currentUser.displayName ?? '').trim().isNotEmpty
        ? widget.currentUser.displayName!.trim()
        : 'You';

    // Theme-aware QR color
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qrColor = isDark ? Colors.white : Colors.black;

    final authPhoto = _authUser?.photoURL;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Tappable avatar (picker)
                GestureDetector(
                  onTap: _chooseAvatar,
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ClipOval(
                      child: (authPhoto != null && authPhoto.isNotEmpty)
                          ? Image.network(
                              authPhoto,
                              key: ValueKey(
                                authPhoto,
                              ), // force rebuild on change
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant,
                              alignment: Alignment.center,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Hey there! I’m using OpenBook',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap avatar to change',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Theme-aware QR
                QrImageView(
                  data: 'openbook://user/${widget.currentUser.uid}',
                  size: 84,
                  gapless: true,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: qrColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: qrColor,
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionHeader(context, 'Preferences'),
          _tile(
            context,
            icon: Icons.person,
            title: 'Account',
            subtitle: 'Profile, number, username',
            onTap: () {},
          ),
          _tile(
            context,
            icon: Icons.lock,
            title: 'Privacy',
            subtitle: 'Last seen, blocked contacts',
            onTap: () {},
          ),
          _tile(
            context,
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Message tones, badges',
            onTap: () {},
          ),

          const SizedBox(height: 16),
          _sectionHeader(context, 'App'),
          _tile(
            context,
            icon: Icons.chat_bubble_outline,
            title: 'Chats',
            subtitle: 'Theme, wallpapers',
            onTap: () {},
          ),
          _tile(
            context,
            icon: Icons.storage,
            title: 'Data & Storage',
            subtitle: 'Network usage, media auto-download',
            onTap: () {},
          ),

          const SizedBox(height: 16),
          _sectionHeader(context, 'Support'),
          _tile(
            context,
            icon: Icons.help_outline,
            title: 'Help',
            subtitle: 'FAQ, contact us',
            onTap: () {},
          ),
          _tile(
            context,
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version, terms',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // --- helpers ---
  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _AvatarItem {
  final String name;
  final String path;
  final String url;
  _AvatarItem({required this.name, required this.path, required this.url});
}
