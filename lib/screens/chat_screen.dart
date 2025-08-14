// ============================================================
// BLOCK A: IMPORTS & MAIN CLASS - START
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <- for SystemSound
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart'; // <- your existing model

class ChatScreen extends StatefulWidget {
  final String chatId;
  final bool isGroupChat;
  final String avatarUrl; // asset/http(s)/storage path (same as before)
  final String chatName; // shown in AppBar
  final UserModel currentUser;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.isGroupChat,
    required this.avatarUrl,
    required this.chatName,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
// ============================================================
// BLOCK A: IMPORTS & MAIN CLASS - END
// ============================================================

// ============================================================
// BLOCK B: STATE, CONFIG, HELPERS - START
//  - TEST/LIVE switch persisted to SharedPreferences
//  - Avatar prefetch logic (group + DM)
//  - Firestore helpers kept compatible with your existing schema
// ============================================================
class _ChatScreenState extends State<ChatScreen> {
  // --- Config ---
  static const String _bucket = 'open-book-16zt1k.firebasestorage.app';
  static const String _prefsKeyTestMode = 'test_mode_enabled';

  // --- Controllers / state ---
  final _messageCtrl = TextEditingController();
  final _listCtrl = ScrollController();

  bool _testMode = true; // default dev-fast; persisted below
  String? _avatarRaw; // may be resolved from Firestore
  String? _otherUid; // for DM avatar fetch
  List<String> _participants = const [];

  // Cached messages stream (compatible with your existing collection)
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream =
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots();

  @override
  void initState() {
    super.initState();
    _avatarRaw = widget.avatarUrl.trim().isNotEmpty ? widget.avatarUrl : null;
    _restoreTestMode();
    _loadParticipants();
    _zeroMyUnreadOnOpen();
    _prefetchAvatarForAppBar();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  // --- SharedPreferences: restore/persist test mode ---
  Future<void> _restoreTestMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _testMode = prefs.getBool(_prefsKeyTestMode) ?? true);
  }

  Future<void> _setTestMode(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyTestMode, v);
    setState(() => _testMode = v);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mode switched to ${v ? 'TEST' : 'LIVE'}')),
    );
  }

  // --- URL helpers / avatar provider ---
  String _toPublicUrl(String value) {
    final v = value.trim();
    if (v.startsWith('http')) return v;
    if (v.startsWith('assets/')) return v;
    final encoded = Uri.encodeComponent(v);
    return 'https://firebasestorage.googleapis.com/v0/b/$_bucket/o/$encoded?alt=media';
  }

  ImageProvider<Object>? _avatarProvider(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (v.startsWith('assets/')) return AssetImage(v);
    final url = v.startsWith('http') ? v : _toPublicUrl(v);
    return NetworkImage(url);
  }

  // --- Firestore helpers ---
  String? _firstNonEmpty(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  Future<void> _prefetchAvatarForAppBar() async {
    if ((_avatarRaw ?? '').trim().isNotEmpty) return;

    try {
      if (widget.isGroupChat) {
        // group: read from chats/{chatId}
        final c = (await FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .get())
            .data();
        final raw = _firstNonEmpty(c, ['imageUrl', 'avatarUrl', 'icon']);
        if (raw != null && mounted) setState(() => _avatarRaw = raw);
      } else {
        // DM: find the other participant
        String? other = _otherUid;
        if (other == null && widget.chatId.startsWith('dm_')) {
          final bits = widget.chatId.substring(3).split('_');
          if (bits.length == 2) {
            final me = widget.currentUser.uid;
            final others = bits.where((u) => u != me).toList();
            if (others.isNotEmpty) other = others.first;
          }
        }
        if (other == null && _participants.isNotEmpty) {
          final me = widget.currentUser.uid;
          final others = _participants.where((u) => u != me).toList();
          if (others.isNotEmpty) other = others.first;
        }
        if (other != null) {
          final u = (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(other)
                  .get())
              .data();
          final raw = _firstNonEmpty(u, [
            'avatarUrl',
            'avatarPath',
            'photoURL',
            'imageUrl',
            'profilePic',
          ]);
          if (raw != null && mounted) setState(() => _avatarRaw = raw);
        }
      }
    } catch (e) {
      // non-fatal
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      final data = snap.data();
      if (data != null && data['participants'] is List) {
        _participants = List<String>.from(data['participants'] as List);
        // set _otherUid hint for DMs
        if (_participants.length == 2) {
          final me = widget.currentUser.uid;
          final others = _participants.where((u) => u != me).toList();
          if (others.isNotEmpty) _otherUid = others.first;
        }
      } else if (widget.chatId.startsWith('dm_')) {
        final bits = widget.chatId.substring(3).split('_');
        if (bits.length == 2) {
          _participants = [bits[0], bits[1]];
          final me = widget.currentUser.uid;
          final others = _participants.where((u) => u != me).toList();
          if (others.isNotEmpty) _otherUid = others.first;
        }
      }
    } catch (_) {}
    await _prefetchAvatarForAppBar();
    if (mounted) setState(() {});
  }

  Future<void> _zeroMyUnreadOnOpen() async {
    final my = widget.currentUser.uid;
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .set({
        'unreadCount': {my: 0},
        'unread': {my: 0},
      }, SetOptions(merge: true));
    } catch (_) {}
  }
  // ============================================================
  // BLOCK B: STATE, CONFIG, HELPERS - END
  // ============================================================

  // ============================================================
  // BLOCK C: SENDING & AUTO-SCROLL - START
  //  - Matches your existing schema updates (lastMessage, unread maps)
  // ============================================================
  Future<void> _sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final senderId = widget.currentUser.uid;
    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    // Add message
    await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderName': widget.currentUser.displayName,
      'text': t,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Participants (for unread counters)
    List<String> parts = _participants;
    if (parts.isEmpty) {
      final chatSnap = await chatRef.get();
      final data = chatSnap.data();
      if (data != null && data['participants'] is List) {
        parts = List<String>.from(data['participants'] as List);
      } else if (widget.chatId.startsWith('dm_')) {
        final bits = widget.chatId.substring(3).split('_');
        if (bits.length == 2) parts = [bits[0], bits[1]];
      }
    }

    // Update chat metadata + unread counters
    final updates = <String, dynamic>{
      'lastMessage': t,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    };
    for (final uid in parts) {
      if (uid == senderId) continue;
      updates['unreadCount.$uid'] = FieldValue.increment(1);
      updates['unread.$uid'] = FieldValue.increment(1);
    }
    try {
      await chatRef.update(updates);
    } catch (_) {
      await chatRef.set(updates, SetOptions(merge: true));
    }

    _messageCtrl.clear();
    _maybeAutoscrollAfterSend();
  }

  void _maybeAutoscrollAfterSend() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listCtrl.hasClients) return;
      final pos = _listCtrl.position;
      final nearBottom = (pos.maxScrollExtent - pos.pixels) < 120;
      if (nearBottom) {
        _listCtrl.animateTo(
          pos.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }
  // ============================================================
  // BLOCK C: SENDING & AUTO-SCROLL - END
  // ============================================================

// ============================================================
// BLOCK D: APP BAR (with TEST/LIVE Switch) - START
// ============================================================
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final img = _avatarProvider(
      (_avatarRaw ?? '').trim().isNotEmpty ? _avatarRaw : widget.avatarUrl,
    );

    final title = widget.chatName.isNotEmpty
        ? widget.chatName
        : (widget.isGroupChat ? 'Group Chat' : 'Direct Chat');

    final String statusText =
        'Having an awesome holiday'; // Replace with real status if dynamic

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          // Back arrow
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          // Avatar with green dot
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[700],
                foregroundImage: img,
                child: img == null
                    ? Text(
                        title.isNotEmpty ? title[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const Positioned(
                bottom: 0,
                right: 0,
                child: _OnlineDot(),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Name + Status stacked (nudged down)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Cooler phone icon
        IconButton(
          tooltip: 'Voice call',
          icon: const Icon(Icons.call_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _FeaturePlaceholder(title: 'Voice Call'),
              ),
            );
          },
        ),
        // Cooler video icon
        IconButton(
          tooltip: 'Video call',
          icon: const Icon(Icons.videocam_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _FeaturePlaceholder(title: 'Video Call'),
              ),
            );
          },
        ),
        // TEST/LIVE pill + toggle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:
                  _testMode ? Colors.green.shade600 : Colors.blueGrey.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _testMode ? 'TEST' : 'LIVE',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Toggle Test/Live',
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => _setTestMode(!_testMode),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
// ============================================================
// BLOCK D: APP BAR (with TEST/LIVE Switch) - END
// ============================================================

// ============================================================
// BLOCK E: MESSAGE LIST (animated + actions) - START
// ============================================================
  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snap) {
        // ---- local helpers ----
        String fmtTime(DateTime dt) {
          final h = dt.hour.toString().padLeft(2, '0');
          final m = dt.minute.toString().padLeft(2, '0');
          return '$h:$m';
        }

        String dateHeaderFor(DateTime dt) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final yesterday = today.subtract(const Duration(days: 1));
          final d = DateTime(dt.year, dt.month, dt.day);
          if (d == today) return 'Today';
          if (d == yesterday) return 'Yesterday';
          return '${dt.day}/${dt.month}/${dt.year}';
        }

        Widget buildTicks(Map<String, dynamic> m) {
          final status = (m['status'] ?? 'sent').toString();
          Widget icon;
          switch (status) {
            case 'read':
              icon = const Icon(Icons.done_all,
                  size: 14, color: Colors.blueAccent);
              break;
            case 'delivered':
              icon = Icon(
                Icons.done_all,
                size: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              );
              break;
            default:
              icon = Icon(
                Icons.check,
                size: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              );
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(key: ValueKey(status), child: icon),
          );
        }

        // WhatsApp-style text bubble with inline time + ticks
        Widget buildBubble(
          String type,
          bool me,
          String text,
          Map<String, dynamic> m,
          DateTime ts,
        ) {
          if (type == 'gif' || type == 'sticker') {
            final url = (m['previewUrl'] ?? m['mediaUrl'] ?? '').toString();
            final w = (m['w'] as num?)?.toDouble() ?? 200;
            final h = (m['h'] as num?)?.toDouble() ?? 200;
            final maxW = MediaQuery.of(context).size.width * .66;
            final scale = (w > 0) ? (maxW / w).clamp(0.4, 1.0) : 1.0;
            final dw = (w * scale).toDouble();
            final dh = (h * scale).toDouble();

            return ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(me ? 12 : 2),
                bottomRight: Radius.circular(me ? 2 : 12),
              ),
              child:
                  Image.network(url, width: dw, height: dh, fit: BoxFit.cover),
            );
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: me ? Colors.blue : Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(me ? 12 : 2),
                bottomRight: Radius.circular(me ? 2 : 12),
              ),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * .78,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.end, // slightly lower than text
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.white, height: 1.22),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  fmtTime(ts),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.1,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 0),
                        blurRadius: 3,
                        color: Colors.black.withOpacity(0.35),
                      ),
                    ],
                  ),
                ),
                if (me) ...[
                  const SizedBox(width: 3),
                  buildTicks(m),
                ],
              ],
            ),
          );
        }

        Future<void> showBottomSheetMenu({
          required bool me,
          required DocumentReference<Map<String, dynamic>> ref,
          required String text,
          required Map<String, dynamic> m,
          required DateTime ts,
        }) async {
          await showModalBottomSheet(
            context: context,
            showDragHandle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            builder: (ctx) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.reply_outlined),
                      title: const Text('Reply'),
                      onTap: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reply coming soon')),
                        );
                      },
                    ),
                    if (text.trim().isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.copy),
                        title: const Text('Copy'),
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: text));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        },
                      ),
                    if (me)
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('Delete for me'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await ref.delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Message deleted')),
                            );
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Delete failed')),
                            );
                          }
                        },
                      ),
                  ],
                ),
              );
            },
          );
        }

        Future<void> showPointerMenu(
          Offset pos, {
          required bool me,
          required DocumentReference<Map<String, dynamic>> ref,
          required String text,
          required Map<String, dynamic> m,
          required DateTime ts,
        }) async {
          await showMenu(
            context: context,
            position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
            items: [
              const PopupMenuItem(value: 'reply', child: Text('Reply')),
              if (text.trim().isNotEmpty)
                const PopupMenuItem(value: 'copy', child: Text('Copy')),
              if (me)
                const PopupMenuItem(
                    value: 'delete', child: Text('Delete for me')),
            ],
          ).then((value) async {
            if (value == 'reply') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reply coming soon')),
              );
            } else if (value == 'copy') {
              await Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            } else if (value == 'delete') {
              try {
                await ref.delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message deleted')),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delete failed')),
                );
              }
            }
          });
        }
        // ---- end helpers ----

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        DateTime? lastDate;
        return ListView.builder(
          controller: _listCtrl,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final m = doc.data();
            final me = m['senderId'] == widget.currentUser.uid;
            final ts =
                (m['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final type = (m['type'] ?? 'text').toString();
            final text = (m['text'] ?? '').toString();

            // Day header
            final currentDate = DateTime(ts.year, ts.month, ts.day);
            Widget? header;
            if (lastDate == null || currentDate != lastDate) {
              header = Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      dateHeaderFor(ts),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
              lastDate = currentDate;
            }

            final bubble = Align(
              alignment: me ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * .78,
                ),
                child: GestureDetector(
                  onLongPress: () => showBottomSheetMenu(
                    me: me,
                    ref: doc.reference,
                    text: text,
                    m: m,
                    ts: ts,
                  ),
                  onSecondaryTapDown: (details) => showPointerMenu(
                    details.globalPosition,
                    me: me,
                    ref: doc.reference,
                    text: text,
                    m: m,
                    ts: ts,
                  ),
                  child: buildBubble(type, me, text, m, ts),
                ),
              ),
            );

            if (header != null) {
              return Padding(
                padding: const EdgeInsets.only(
                    bottom: 8), // space after header+bubble
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, bubble],
                ),
              );
            }

            return Padding(
              padding:
                  const EdgeInsets.only(bottom: 8), // space after each bubble
              child: bubble,
            );
          },
        );
      },
    );
  }
// ============================================================
// BLOCK E: MESSAGE LIST (animated + actions) - END
// ============================================================

  // ============================================================
// BLOCK F: COMPOSER BAR (WhatsApp-like) - START
// ============================================================
  Widget _buildComposerBar() {
    final hasText = _messageCtrl.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        height: 56,
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            if (!hasText) ...[
              IconButton(
                tooltip: 'Camera',
                icon: const Icon(Icons.camera_alt, size: 24),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Camera (coming soon)')),
                  );
                },
              ),
              IconButton(
                tooltip: 'Mic',
                icon: const Icon(Icons.mic, size: 24),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voice message (soon)')),
                  );
                },
              ),
            ],
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageCtrl,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Type a message',
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (v) => _sendText(v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Emoji',
                      icon: const Icon(Icons.emoji_emotions_outlined, size: 24),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Emoji picker (soon)')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: hasText ? 'Send' : 'More',
              icon: Icon(
                hasText ? Icons.send : Icons.add,
                size: 24,
                color: hasText
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              onPressed: hasText ? () => _sendText(_messageCtrl.text) : null,
            ),
          ],
        ),
      ),
    );
  }
// ============================================================
// BLOCK F: COMPOSER BAR (WhatsApp-like) - END
// ============================================================

  // ============================================================
  // BLOCK G: PAGE BUILD (layout & background) - START
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F1420), Color(0xFF1B2230)],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildComposerBar(),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BLOCK G: PAGE BUILD (layout & background) - END
  // ============================================================
}

// ============================================================
// BLOCK H: SMALL SHARED WIDGETS - START
// ============================================================
class _OnlineDot extends StatelessWidget {
  const _OnlineDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: Colors.greenAccent.shade400,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  final String title;
  const _FeaturePlaceholder({Key? key, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title\n(coming soon)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

// ============================================================
// BLOCK H: SMALL SHARED WIDGETS - END
// ============================================================
