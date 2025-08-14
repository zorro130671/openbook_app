// lib/screens/dev_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DevAuthScreen extends StatefulWidget {
  const DevAuthScreen({super.key});

  @override
  State<DevAuthScreen> createState() => _DevAuthScreenState();
}

class _DevAuthScreenState extends State<DevAuthScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController(text: '123456');
  bool _useSharedPw = true;
  bool _obscure = true;
  bool _busy = false;

  // ===== Avatar helpers (same approach as Home) =====
  static const String _bucket = 'open-book-16zt1k.firebasestorage.app';

  String _toAvatarUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http')) return value;
    if (value.startsWith('assets/')) return value;
    final encoded = Uri.encodeComponent(value);
    return 'https://firebasestorage.googleapis.com/v0/b/$_bucket/o/$encoded?alt=media';
  }

  ImageProvider<Object>? _avatarProvider(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (v.startsWith('assets/')) return AssetImage(v);
    final url = v.startsWith('http') ? v : _toAvatarUrl(v);
    return NetworkImage(url);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    final m = ScaffoldMessenger.of(context);

    if (email.isEmpty || pw.isEmpty) {
      m.showSnackBar(
        const SnackBar(content: Text('Email and password required.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );
      m.showSnackBar(SnackBar(content: Text('Signed in as $email')));
      if (mounted) Navigator.pop(context, true); // tell caller to refresh
    } on FirebaseAuthException catch (e) {
      m.showSnackBar(SnackBar(content: Text('Auth error: ${e.code}')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in (dev)')),
      body: Column(
        children: [
          // --- Form ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'user@openbook.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _useSharedPw,
                      onChanged: (v) {
                        setState(() {
                          _useSharedPw = v ?? true;
                          if (_useSharedPw) _pwCtrl.text = '123456';
                        });
                      },
                    ),
                    const Text('Use shared password (123456)'),
                  ],
                ),
                TextField(
                  controller: _pwCtrl,
                  enabled: !_useSharedPw,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      tooltip: _obscure ? 'Show' : 'Hide',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _signIn,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Sign in'),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 0),

          // --- Users from Firestore: tap to prefill email ---
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('displayName')
                  .limit(200)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final m = docs[i].data();
                    final name = (m['displayName'] ?? '') as String;
                    final email = (m['email'] ?? '') as String;
                    final avatarRaw =
                        (m['avatarUrl'] ??
                                m['avatarPath'] ??
                                m['photoURL'] ??
                                '')
                            as String;
                    final isOnline = (m['isOnline'] ?? false) as bool;

                    final img = _avatarProvider(avatarRaw);
                    final initial = (name.isNotEmpty ? name[0] : '?')
                        .toUpperCase();

                    return ListTile(
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
                            // Avatar with initials fallback; photo overlays when available
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[700],
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              foregroundImage: img, // may be null
                            ),
                            // Online dot
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.shortcut),
                      onTap: () {
                        _emailCtrl.text = email;
                        if (_useSharedPw) _pwCtrl.text = '123456';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Email filled: $email'),
                            duration: const Duration(milliseconds: 900),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
