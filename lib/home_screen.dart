// lib/home_screen.dart

import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'screens/quick_links_screen.dart';

import 'models/user_model.dart';
import 'screens/chat_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/ai_hub_screen.dart';
import 'screens/new_chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/me_screen.dart';
import 'utils/custom_routes.dart';
import 'screens/privacy_control_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/dev_auth_screen.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;

enum ChatFilter { all, unread, favorite, groups }

// ====== Demo users (fallback only) ======
final List<UserModel> demoUsers = [
  UserModel(
    uid: 'NhY1NzNu0FgCPCvboeHSPqoy7Ng2',
    displayName: 'Zah Martin',
    email: 'zah@openbook.com',
    avatarUrl: 'assets/images/avatars/zah_avatar.png',
    statusMessage: 'Available',
    isOnline: true,
  ),
  UserModel(
    uid: 'wv2OJVWg8fPo1qZTN483QGqyt132',
    displayName: 'Sumitra Nathan',
    email: 'sumitra@openbook.com',
    avatarUrl: 'assets/images/avatars/sumitra_avatar.png',
    statusMessage: 'Feeling amazing ✨',
    isOnline: true,
  ),
  UserModel(
    uid: 'XenOj61VJRc7rMmrPykMNIMhr',
    displayName: 'Liam Wong',
    email: 'liam@openbook.com',
    avatarUrl: 'assets/images/avatars/liam_avatar.png',
    statusMessage: 'Busy',
    isOnline: false,
  ),
];

// ===== Dev switcher model =====
class _DevUser {
  final String label;
  final String email;
  final String password;
  const _DevUser(this.label, this.email, this.password);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  UserModel? _currentUser;

  // UI state
  int _selectedIndex = 0;
  ChatFilter _filter = ChatFilter.all;

  // search
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchText = '';

  // favorites (store chatIds)
  final Set<String> _favoriteChatIds = {};

  // cached list for Contacts screen (dev)
  List<UserModel> _lastUsers = const [];

  final Random _rand = Random();

  // translate prefs (Quick Actions)
  bool _autoTranslate = false;
  String _targetLang = 'en';

  // Dev users
  static const _DEV_USERS = <_DevUser>[
    _DevUser('Zah Martin', 'Test1@openbook.com', '123456'),
    _DevUser('Sumitra Nathan', 'Test2@openbook.com', '123456'),
    _DevUser('Liam Wong', 'Test3@openbook.com', '123456'),
  ];

  StreamSubscription<User?>? _authSub;

  // ===== Avatar helpers =====
  static const String _bucket = 'open-book-16zt1k.firebasestorage.app';

  String _toAvatarUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http')) return value; // already full URL
    if (value.startsWith('assets/')) return value; // local asset
    final encoded = Uri.encodeComponent(value);
    // NOTE: this is the exact form you were using when it worked for you
    return 'https://firebasestorage.googleapis.com/v0/b/$_bucket/o/$encoded?alt=media';
  }

  // Null-safe provider for ListTiles etc.
  ImageProvider<Object>? _avatarProvider(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (v.startsWith('assets/')) return AssetImage(v);
    final url = v.startsWith('http') ? v : _toAvatarUrl(v);
    return NetworkImage(url);
  }

  // AVATAR (initials always visible; image overlays when available)
  Widget _avatar(UserModel u) => SizedBox(
    width: 48,
    height: 48,
    child: Builder(
      builder: (context) {
        ImageProvider<Object>? img;
        final raw = (u.avatarUrl ?? '').trim();
        if (raw.isNotEmpty) {
          if (raw.startsWith('assets/')) {
            img = AssetImage(raw);
          } else {
            final url = raw.startsWith('http') ? raw : _toAvatarUrl(raw);
            img = NetworkImage(url);
          }
        }
        final initial = (u.displayName.isNotEmpty ? u.displayName[0] : '?')
            .toUpperCase();

        return CircleAvatar(
          backgroundColor: Colors.grey[700],
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          foregroundImage: img, // may be null → initials stay
        );
      },
    ),
  );

  @override
  void initState() {
    super.initState();

    // live refresh when auth changes
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (!mounted) return;
      setState(() {
        if (u == null) {
          _currentUser = null;
        } else {
          _currentUser = UserModel(
            uid: u.uid,
            displayName: u.displayName ?? (u.email ?? 'You'),
            email: u.email ?? '',
            avatarUrl: u.photoURL ?? 'assets/images/avatars/zah_avatar.png',
            statusMessage: 'Available',
            isOnline: true,
          );
        }
      });
    });

    // search debounce
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _searchText = _searchCtrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===== Time formatting (WhatsApp-like) =====
  String _formatWhatsappTime(DateTime dt) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final diff = now.difference(dt);

    if (dt.isAfter(todayStart)) return DateFormat.jm().format(dt); // 3:45 PM
    if (diff.inDays < 7) return DateFormat.E().format(dt); // Mon/Tue
    return DateFormat('M/d/yy').format(dt); // 8/3/25
  }

  int _unreadFromDoc(String myUid, Map<String, dynamic>? unread) {
    if (unread == null) return 0;
    final v = unread[myUid];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  // ===== Chat creation/open =====
  String _directChatId(String a, String b) {
    final pair = [a, b]..sort();
    return 'dm_${pair[0]}_${pair[1]}';
  }

  Future<T?> _pushSmooth<T>(Widget page) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 230),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) {
          final offset = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim);
          final fade = CurvedAnimation(parent: anim, curve: Curves.easeOutQuad);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: offset, child: child),
          );
        },
      ),
    );
  }

  Future<void> _openOrCreateDirectChat(UserModel other) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in via the dev switcher or Dev Sign-in first.'),
        ),
      );
      return;
    }

    final chatId = _directChatId(myUid, other.uid);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    final snap = await chatRef.get();
    if (!snap.exists) {
      await chatRef.set({
        'chatId': chatId,
        'isGroup': false,
        'participants': [myUid, other.uid],
        'participantNames': [
          _currentUser?.displayName ?? 'You',
          other.displayName,
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        // write both timestamp fields for compatibility
        'lastMessageTimestamp':
            FieldValue.serverTimestamp(), // live field (used by your query)
        'lastMessageAt': FieldValue.serverTimestamp(), // compat
        // write both unread maps for compatibility
        'unreadCount': {myUid: 0, other.uid: 0}, // live field
        'unread': {myUid: 0, other.uid: 0}, // compat
      });
    }

    // Mark my unread as read when opening (don’t clobber the other user)
    try {
      await chatRef.update({
        'unreadCount.$myUid': 0, // live field
        'unread.$myUid': 0, // compat
      });
    } catch (_) {
      // If fields don’t exist yet, merge-create safely
      await chatRef.set({
        'unreadCount': {myUid: 0},
        'unread': {myUid: 0},
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    await _pushSmooth(
      ChatScreen(
        currentUser: _currentUser!, // guarded by sign-in above
        chatId: chatId,
        chatName: other.displayName,
        avatarUrl: _toAvatarUrl(other.avatarUrl),
        isGroupChat: false,
      ),
    );
  }

  // ===== CHATS (Home list) =====
  String _otherName(List<dynamic>? names, String myName) {
    if (names == null || names.isEmpty) return 'Chat';
    if (names.length == 1) return names.first.toString();
    for (final n in names) {
      final s = (n ?? '').toString();
      if (s.isEmpty) continue;
      if (!s.toLowerCase().contains(myName.toLowerCase())) return s;
    }
    return names.first.toString();
  }

  Widget _buildChatsList() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 12),
          Text('Sign in to see your chats.'),
        ],
      );
    }

    final chatsQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageTimestamp', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: chatsQuery.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final docs = snap.data?.docs ?? const [];
        final meName = _currentUser?.displayName ?? 'You';

        // Build rows
        var rows = docs.map((d) {
          final m = d.data();
          final isGroup = (m['isGroup'] == true);
          final names = (m['participantNames'] as List?)?.cast<dynamic>();
          final chatName = isGroup
              ? (m['chatName'] ?? _otherName(names, '')) as String
              : _otherName(names, meName);

          final lastTs =
              (m['lastMessageTimestamp'] as Timestamp?)
                  ?.toDate() ?? // your live field
              (m['lastMessageAt'] as Timestamp?)?.toDate() ?? // fallback
              (m['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now().subtract(
                Duration(minutes: 1 + _rand.nextInt(4000)),
              );

          final unread = _unreadFromDoc(
            myUid,
            (m['unreadCount'] as Map?)?.cast<String, dynamic>() ??
                (m['unread'] as Map?)?.cast<String, dynamic>(),
          );

          final chatId = (m['chatId'] ?? d.id).toString();
          final lastMsg = (m['lastMessage'] ?? '').toString();
          final avatarUrl = (m['avatarUrl'] ?? '').toString();

          return _ChatRow(
            chatId: chatId,
            isGroup: isGroup,
            title: chatName,
            avatarUrl: avatarUrl,
            lastMessage: lastMsg,
            lastTime: lastTs,
            unread: unread,
          );
        }).toList();

        // Search filter
        if (_searchText.isNotEmpty) {
          final q = _searchText.toLowerCase();
          rows = rows.where((r) => r.title.toLowerCase().contains(q)).toList();
        }

        // Filters
        switch (_filter) {
          case ChatFilter.unread:
            rows = rows.where((r) => r.unread > 0).toList();
            break;
          case ChatFilter.favorite:
            rows = rows
                .where((r) => _favoriteChatIds.contains(r.chatId))
                .toList();
            break;
          case ChatFilter.groups:
            rows = rows.where((r) => r.isGroup).toList();
            break;
          case ChatFilter.all:
          default:
            break;
        }

        if (rows.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: const [
              Text(
                'No chats yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text('Tap + to start a conversation.'),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(
            height: 0,
            indent: 72,
            endIndent: 12,
            thickness: 0.6,
            color: Theme.of(context).dividerColor.withOpacity(0.35),
          ),
          itemBuilder: (_, i) => _chatTile(rows[i]),
        );
      },
    );
  }

  // ===== Chat tile =====
  Widget _chatTile(_ChatRow row) {
    final titleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.80),
    );

    final tsText = _formatWhatsappTime(row.lastTime);
    final tsColor = row.unread > 0 ? Colors.blue : Theme.of(context).hintColor;
    final tsStyle = TextStyle(
      fontSize: 12,
      color: tsColor,
      fontWeight: row.unread > 0 ? FontWeight.w600 : FontWeight.w400,
    );

    final unreadText = row.unread > 99 ? '99+' : '${row.unread}';

    // LEADING AVATAR (stream the other user's profile if this is a 1:1 chat)
    Widget leading;
    leading = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(row.chatId)
          .snapshots(),
      builder: (context, chatSnap) {
        String name = row.title;
        String avatar = row.avatarUrl; // may be empty

        // Try to derive the other UID for 1:1
        String? otherUid;
        final chatData = chatSnap.data?.data();
        if (chatData != null &&
            (chatData['isGroup'] != true) &&
            chatData['participants'] is List) {
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          final parts = (chatData['participants'] as List).cast<String>();
          otherUid = parts.firstWhere((p) => p != myUid, orElse: () => '');
          if (otherUid!.isEmpty) otherUid = null;
        }

        if (otherUid == null) {
          // Fallback: initials only (group or unknown)
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          return SizedBox(
            width: 48,
            height: 48,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[300],
              child: Text(
                initial,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }

        // Stream users/{otherUid} to get live avatarUrl/displayName
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(otherUid)
              .snapshots(),
          builder: (context, userSnap) {
            if (userSnap.hasData && userSnap.data?.data() != null) {
              final m = userSnap.data!.data()!;
              name = (m['displayName'] ?? name).toString();
              avatar =
                  (m['avatarUrl'] ?? m['avatarPath'] ?? m['photoURL'] ?? avatar)
                      .toString();
            }
            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
            return SizedBox(
              width: 48,
              height: 48,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                foregroundImage: _avatarProvider(avatar), // assets or https
                child: Text(
                  initial,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
          },
        );
      },
    );

    return ListTile(
      leading: leading,
      title: Text(
        row.title,
        style: titleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        row.lastMessage.isNotEmpty ? row.lastMessage : 'Tap to chat',
        style: subtitleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tsText,
              style: tsStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (row.unread > 0)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              const SizedBox(height: 20),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      horizontalTitleGap: 12,
      minLeadingWidth: 0,
      dense: false,
      onTap: () async {
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(row.chatId);
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        if (myUid != null) {
          await chatRef.set({
            'unread': {myUid: 0},
            'unreadCount': {myUid: 0},
          }, SetOptions(merge: true));
        }
        await _pushSmooth(
          ChatScreen(
            currentUser: _currentUser!,
            chatId: row.chatId,
            chatName: row.title,
            avatarUrl: _toAvatarUrl(row.avatarUrl),
            isGroupChat: row.isGroup,
          ),
        );
      },
      onLongPress: () {
        setState(() {
          if (_favoriteChatIds.contains(row.chatId)) {
            _favoriteChatIds.remove(row.chatId);
          } else {
            _favoriteChatIds.add(row.chatId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _favoriteChatIds.contains(row.chatId)
                  ? 'Added to Favorites'
                  : 'Removed from Favorites',
            ),
          ),
        );
      },
    );
  }

  // ---------- Start Chat picker (for + button) ----------
  Future<void> _openStartChatPicker() async {
    final usersCol = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayName');

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: usersCol.snapshots(),
          builder: (context, snap) {
            List<UserModel> users;
            if (snap.hasData && snap.data!.docs.isNotEmpty) {
              users = snap.data!.docs.map((d) {
                final m = d.data();
                final avatarRaw =
                    (m['avatarUrl'] ?? m['avatarPath'] ?? m['photoURL'] ?? '')
                        .toString();
                return UserModel.fromMap({
                  ...m,
                  'uid': d.id,
                  'avatarUrl': avatarRaw,
                });
              }).toList();
            } else {
              users = List<UserModel>.from(demoUsers);
            }

            // hide me
            final myUid = FirebaseAuth.instance.currentUser?.uid;
            if (myUid != null) {
              users = users.where((u) => u.uid != myUid).toList();
            }

            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final u = users[i];
                return ListTile(
                  leading: SizedBox(
                    width: 42,
                    height: 42,
                    child: CircleAvatar(
                      backgroundImage: _avatarProvider(u.avatarUrl),
                    ),
                  ),
                  title: Text(
                    u.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    u.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _openOrCreateDirectChat(u);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------- Quick Actions (centered control center) ----------
  Future<void> _openQuickPanel() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick actions',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardColor = isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.9);

        return Stack(
          children: [
            // Backdrop blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: const SizedBox.expand(),
            ),
            // Centered card
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: _buildQuickGrid(ctx),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildQuickGrid(BuildContext modalCtx) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      children: [
        _TranslateTile(
          lang: _targetLang,
          autoTranslate: _autoTranslate,
          onToggle: (v) => setState(() => _autoTranslate = v),
          onLang: (l) => setState(() => _targetLang = l),
        ),
        _QuickTile(
          label: 'Privacy',
          iconData: Icons.shield_outlined,
          onTap: () {
            Navigator.of(modalCtx).pop();
            Navigator.of(context).push(fadeRoute(const PrivacyControlScreen()));
          },
        ),
        _QuickTile(
          label: 'Documents',
          iconData: Icons.description_outlined,
          onTap: () {
            Navigator.of(modalCtx).pop();
            if (_currentUser == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please sign in to view Documents'),
                ),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DocumentsScreen(currentUser: _currentUser!),
              ),
            );
          },
        ),
        _QuickTile(
          label: 'More',
          iconData: Icons.more_horiz,
          onTap: () {
            Navigator.of(modalCtx).pop();
            _openSettings();
          },
        ),
      ],
    );
  }

  Color _langTint(String lang) {
    switch (lang) {
      case 'en':
        return const Color(0xFF1E3A8A);
      case 'ar':
        return const Color(0xFF059669);
      case 'hi':
        return const Color(0xFFEA580C);
      case 'ja':
        return const Color(0xFFDC2626);
      case 'es':
        return const Color(0xFFCA8A04);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  // ---------- Top filter chips ----------
  Widget _filterChips() {
    final selectedBg = Theme.of(context).colorScheme.primary;
    final selectedFg = Colors.white;

    Widget chip(String label, ChatFilter value) {
      final selected = _filter == value;
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? selectedFg
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        showCheckmark: false,
        selected: selected,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: selectedBg,
        side: BorderSide(
          color: selected ? selectedBg : Theme.of(context).dividerColor,
        ),
        onSelected: (_) => setState(() => _filter = value),
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        chip('All', ChatFilter.all),
        chip('Unread', ChatFilter.unread),
        chip('Favorites', ChatFilter.favorite),
        chip('Groups', ChatFilter.groups),
      ],
    );
  }

  // ------- Platform-auth Bottom Nav (with small blue dot) -------
  Widget _buildBottomNav() {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final topHairline = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    final bgColorAndroid = isDark ? const Color(0xFF111111) : Colors.white;
    final tintIOS = isDark
        ? Colors.black.withOpacity(0.35)
        : Colors.white.withOpacity(0.70);

    final bar = SizedBox(
      height: 60, // icons + dot inside; no overflow
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        iconSize: 24,
        selectedFontSize: 0,
        unselectedFontSize: 0,
        selectedItemColor: isDark ? Colors.white : Colors.black,
        unselectedItemColor: (isDark ? Colors.white : Colors.black).withOpacity(
          0.65,
        ),
        onTap: (i) async {
          HapticFeedback.selectionClick();
          if (mounted) setState(() => _selectedIndex = i); // triggers icon anim
          if (i != 0)
            await Future.delayed(
              const Duration(milliseconds: 120),
            ); // let it animate
          switch (i) {
            case 0:
              break;
            case 1:
              await _pushSmooth(ContactsScreen(contacts: _lastUsers));
              break;
            case 2:
              await _pushSmooth(const AIHubScreen());
              break;
            case 3:
              await _pushSmooth(
                MeScreen(
                  uid: _currentUser?.uid ?? '',
                  displayName: _currentUser?.displayName ?? 'Me',
                  avatarUrl: _currentUser?.avatarUrl ?? '',
                ),
              );
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            label: '',
            icon: _AnimatedNavIcon(
              icon: Icons.chat_bubble_outline,
              selected: _selectedIndex == 0,
            ),
          ),
          BottomNavigationBarItem(
            label: '',
            icon: _AnimatedNavIcon(
              icon: Icons.group_outlined,
              selected: _selectedIndex == 1,
            ),
          ),
          BottomNavigationBarItem(
            label: '',
            icon: _AnimatedNavIcon(
              icon: Icons.smart_toy_outlined, // AI robot
              selected: _selectedIndex == 2,
            ),
          ),
          BottomNavigationBarItem(
            label: '',
            icon: _AnimatedNavIcon(
              icon: Icons.person_outlined,
              selected: _selectedIndex == 3,
            ),
          ),
        ],
      ),
    );

    if (isIOS) {
      return ClipRect(
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: topHairline, width: 0.5)),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: tintIOS,
              child: SafeArea(top: false, child: bar),
            ),
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: bgColorAndroid,
          border: Border(top: BorderSide(color: topHairline, width: 0.5)),
        ),
        child: SafeArea(top: false, child: bar),
      );
    }
  }

  void _openSettings() {
    if (_currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in first.')));
      return;
    }
    _pushSmooth(SettingsScreen(currentUser: _currentUser!));
  }

  void _openMe() {
    final u = _currentUser;
    if (u == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in first.')));
      return;
    }
    _pushSmooth(
      MeScreen(uid: u.uid, displayName: u.displayName, avatarUrl: u.avatarUrl),
    );
  }

  void _openNewChat() {
    _openStartChatPicker(); // now opens a live picker and then creates/opens chat
  }

  Future<void> _openDevAuth() async {
    final refreshNeeded = await _pushSmooth(const DevAuthScreen());
    if (refreshNeeded == true) {
      if (mounted) setState(() {});
    }
  }

  void _openQuickLinks() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickLinksScreen(
          initialTranslate: _autoTranslate,
          initialLang: _targetLang,
          currentUser: _currentUser,
          onTranslateChanged: (v) => setState(() => _autoTranslate = v),
          onLangChanged: (l) => setState(() => _targetLang = l),
        ),
      ),
    );
  }

  Future<void> _showDevSwitcher() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Switch user (quick dev)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final u in _DEV_USERS)
              ListTile(
                leading: const Icon(Icons.switch_account),
                title: Text(u.label),
                subtitle: Text(u.email),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _devSignIn(u);
                },
              ),
            const SizedBox(height: 12),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.developer_mode),
              title: const Text('Sign in as any user…'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openDevAuth();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _devSignIn(_DevUser u) async {
    final messenger = ScaffoldMessenger.of(context);
    final email = u.email.trim().toLowerCase();
    final password = u.password.trim();

    try {
      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      messenger.showSnackBar(
        SnackBar(content: Text('Signed in as ${u.label}')),
      );
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Auth error: ${e.code}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _currentUser != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.apps),
          onPressed: _openQuickLinks,
          tooltip: 'Quick actions',
        ),
        title: const Text('OpenBook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _openNewChat,
            tooltip: 'New chat',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'dev_switch') _showDevSwitcher();
              if (v == 'dev_auth') _openDevAuth();
              if (v == 'sign_out') FirebaseAuth.instance.signOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'dev_switch',
                child: Text('Switch user (quick dev)'),
              ),
              const PopupMenuItem(
                value: 'dev_auth',
                child: Text('Sign in as any user…'),
              ),
              if (signedIn)
                const PopupMenuItem(value: 'sign_out', child: Text('Sign out')),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          if (!signedIn)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'You are signed out. Use the Apps button for quick actions, or menu for dev sign-in.',
              ),
            ),

          // Search (WhatsApp sizing)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36, maxHeight: 36),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 12,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _filterChips(),
          ),

          // Chats list
          Expanded(child: _buildChatsList()),
        ],
      ),

      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

// ===== Spinning globe =====
class _SpinningGlobe extends StatefulWidget {
  final bool spinning;
  final Color color;
  const _SpinningGlobe({required this.spinning, this.color = Colors.blue});

  @override
  State<_SpinningGlobe> createState() => _SpinningGlobeState();
}

class _SpinningGlobeState extends State<_SpinningGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    if (!widget.spinning) _ctrl.stop();
  }

  @override
  void didUpdateWidget(covariant _SpinningGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.spinning && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(Icons.public, size: 28, color: widget.color),
    );
  }
}

// ===== Translate tile (switch + dropdown inside) =====
class _TranslateTile extends StatelessWidget {
  final String lang;
  final bool autoTranslate;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onLang;
  const _TranslateTile({
    required this.lang,
    required this.autoTranslate,
    required this.onToggle,
    required this.onLang,
  });

  Color _tint(String l) {
    switch (l) {
      case 'en':
        return const Color(0xFF1E3A8A);
      case 'ar':
        return const Color(0xFF059669);
      case 'hi':
        return const Color(0xFFEA580C);
      case 'ja':
        return const Color(0xFFDC2626);
      case 'es':
        return const Color(0xFFCA8A04);
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tint(lang);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {}, // controls inside
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SpinningGlobe(spinning: autoTranslate, color: Colors.blue),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Translate',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: 0.92,
                    child: Switch.adaptive(
                      value: autoTranslate,
                      onChanged: onToggle,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tint.withOpacity(.6)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: lang,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onChanged: (l) {
                      if (l != null) onLang(l);
                    },
                    items: ['en', 'ar', 'hi', 'ja', 'es'].map((l) {
                      final t = _tint(l);
                      return DropdownMenuItem(
                        value: l,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: t,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l.toUpperCase(),
                              style: TextStyle(
                                color: t,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Quick action tile =====
class _QuickTile extends StatelessWidget {
  final String label;
  final IconData? iconData;
  final Widget? icon;
  final VoidCallback onTap;
  const _QuickTile({
    required this.label,
    this.iconData,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final childIcon = icon ?? Icon(iconData, size: 28);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              childIcon,
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Animated nav icon (fixed 32x32 box; lift+scale; small blue dot) ---
class _AnimatedNavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _AnimatedNavIcon({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            offset: selected ? const Offset(0, -0.06) : Offset.zero,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              scale: selected ? 1.12 : 1.0,
              child: Icon(icon, size: 24),
            ),
          ),
          Positioned(
            bottom: 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: selected ? 1 : 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Chat row VM =====
class _ChatRow {
  final String chatId;
  final bool isGroup;
  final String title;
  final String avatarUrl;
  final String lastMessage;
  final DateTime lastTime;
  final int unread;

  _ChatRow({
    required this.chatId,
    required this.isGroup,
    required this.title,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastTime,
    required this.unread,
  });
}

// ------------------- Dock item model (unused; kept for reference) -------------------
class _DockItem {
  final IconData icon;
  final String label;
  const _DockItem(this.icon, this.label);
}
