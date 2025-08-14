// app/lib/screens/documents_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';

enum DocumentStatus { pending, signed, declined, expired }

class DocumentSigner {
  final String uid;
  final String name;
  final String email;
  final int order;
  final DateTime? signedAt;

  DocumentSigner({
    required this.uid,
    required this.name,
    required this.email,
    this.order = 1,
    this.signedAt,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'order': order,
    'signedAt': signedAt?.millisecondsSinceEpoch,
  };

  static DocumentSigner fromMap(Map<String, dynamic> m) => DocumentSigner(
    uid: m['uid'] ?? '',
    name: m['name'] ?? '',
    email: m['email'] ?? '',
    order: (m['order'] ?? 1) as int,
    signedAt: m['signedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(m['signedAt'])
        : null,
  );

  DocumentSigner copyWith({DateTime? signedAt}) => DocumentSigner(
    uid: uid,
    name: name,
    email: email,
    order: order,
    signedAt: signedAt ?? this.signedAt,
  );
}

class DocumentModel {
  final String id;
  final String title;
  final String fileUrl;
  final String mimeType; // e.g., application/pdf
  final String ownerId;
  final List<String> participants; // uids
  final List<String> tags;
  final DocumentStatus status;
  final List<DocumentSigner> signers;
  final String? chatId; // source chat
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueAt;
  final int? sizeBytes;

  DocumentModel({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.mimeType,
    required this.ownerId,
    required this.participants,
    required this.tags,
    required this.status,
    required this.signers,
    required this.createdAt,
    required this.updatedAt,
    this.dueAt,
    this.chatId,
    this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'fileUrl': fileUrl,
    'mimeType': mimeType,
    'ownerId': ownerId,
    'participants': participants,
    'tags': tags,
    'status': status.name,
    'signers': signers.map((s) => s.toMap()).toList(),
    'chatId': chatId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'dueAt': dueAt?.millisecondsSinceEpoch,
    'sizeBytes': sizeBytes,
  };

  static DocumentModel fromSnapshot(DocumentSnapshot snap) {
    final m = (snap.data() as Map<String, dynamic>? ?? {});
    return DocumentModel(
      id: snap.id,
      title: m['title'] ?? 'Untitled',
      fileUrl: m['fileUrl'] ?? '',
      mimeType: m['mimeType'] ?? 'application/pdf',
      ownerId: m['ownerId'] ?? '',
      participants: (m['participants'] as List?)?.cast<String>() ?? const [],
      tags: (m['tags'] as List?)?.cast<String>() ?? const [],
      status: _statusFromString(m['status']),
      signers: ((m['signers'] as List?) ?? [])
          .map((x) => DocumentSigner.fromMap(Map<String, dynamic>.from(x)))
          .toList(),
      chatId: m['chatId'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] ?? 0),
      dueAt: m['dueAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['dueAt'])
          : null,
      sizeBytes: m['sizeBytes'],
    );
  }

  static DocumentStatus _statusFromString(String? s) {
    switch (s) {
      case 'signed':
        return DocumentStatus.signed;
      case 'declined':
        return DocumentStatus.declined;
      case 'expired':
        return DocumentStatus.expired;
      case 'pending':
      default:
        return DocumentStatus.pending;
    }
  }

  DocumentModel copyWith({
    DocumentStatus? status,
    List<DocumentSigner>? signers,
    DateTime? updatedAt,
  }) {
    return DocumentModel(
      id: id,
      title: title,
      fileUrl: fileUrl,
      mimeType: mimeType,
      ownerId: ownerId,
      participants: participants,
      tags: tags,
      status: status ?? this.status,
      signers: signers ?? this.signers,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueAt: dueAt,
      chatId: chatId,
      sizeBytes: sizeBytes,
    );
  }
}

enum _Filter { all, received, sent, pending, signed, expiring }

class DocumentsScreen extends StatefulWidget {
  final UserModel currentUser;
  const DocumentsScreen({super.key, required this.currentUser});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const bool _useMock = true;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _Filter _activeFilter = _Filter.all;
  bool _asGrid = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });
  }

  Stream<List<DocumentModel>> _stream() {
    if (_useMock) {
      return Stream.value(_mockDocs(widget.currentUser.uid));
    }
    final q = FirebaseFirestore.instance
        .collection('documents')
        .where('participants', arrayContains: widget.currentUser.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();

    return q.map((snap) => snap.docs.map(DocumentModel.fromSnapshot).toList());
  }

  List<DocumentModel> _applyFilters(List<DocumentModel> docs) {
    List<DocumentModel> list = docs;

    list = switch (_activeFilter) {
      _Filter.all => list,
      _Filter.received =>
        list.where((d) => d.ownerId != widget.currentUser.uid).toList(),
      _Filter.sent =>
        list.where((d) => d.ownerId == widget.currentUser.uid).toList(),
      _Filter.pending =>
        list.where((d) => d.status == DocumentStatus.pending).toList(),
      _Filter.signed =>
        list.where((d) => d.status == DocumentStatus.signed).toList(),
      _Filter.expiring => list.where((d) => _isExpiringSoon(d.dueAt)).toList(),
    };

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (d) =>
                d.title.toLowerCase().contains(q) ||
                d.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }
    return list;
  }

  static bool _isExpiringSoon(DateTime? due) {
    if (due == null) return false;
    final now = DateTime.now();
    return due.isAfter(now) && due.isBefore(now.add(const Duration(days: 7)));
  }

  void _toggleLayout() => setState(() => _asGrid = !_asGrid);

  Future<void> _openSignatureLibrary() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _ManageSignaturesScreen()));
    // no further action; library is global via SharedPreferences
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            tooltip: 'Signatures',
            onPressed: _openSignatureLibrary,
            icon: const Icon(Icons.draw_rounded),
          ),
          IconButton(
            tooltip: 'Toggle layout',
            onPressed: _toggleLayout,
            icon: Icon(
              _asGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Upload',
            onPressed: _onUploadTap,
            icon: const Icon(Icons.upload_file_rounded),
          ),
          PopupMenuButton<String>(
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'newTemplate',
                child: Text('Create from template'),
              ),
            ],
            onSelected: (v) {
              if (v == 'newTemplate') _showSnack('Template flow (stub)');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search documents, tags, or people…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: _Filter.values.map((f) {
                final selected = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: selected,
                    label: Text(_filterLabel(f)),
                    onSelected: (_) => setState(() => _activeFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          // List/Grid
          Expanded(
            child: StreamBuilder<List<DocumentModel>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = _applyFilters(snap.data ?? const []);
                if (docs.isEmpty) {
                  return _EmptyState(onUploadTap: _onUploadTap);
                }
                if (_asGrid) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.25,
                        ),
                    itemCount: docs.length,
                    itemBuilder: (_, i) => _DocumentCard(
                      doc: docs[i],
                      currentUserId: widget.currentUser.uid,
                      onOpen: () => _openDetails(docs[i]),
                      onMore: (rect) => _showDocActions(docs[i], rect),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _DocumentTile(
                    doc: docs[i],
                    currentUserId: widget.currentUser.uid,
                    onTap: () => _openDetails(docs[i]),
                    onMore: (rect) => _showDocActions(docs[i], rect),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onUploadTap,
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('New'),
      ),
    );
  }

  void _openDetails(DocumentModel doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DocumentDetailScreen(
          doc: doc,
          currentUserId: widget.currentUser.uid,
          onSignComplete: (signedDoc) async {
            if (!_useMock) {
              await FirebaseFirestore.instance
                  .collection('documents')
                  .doc(signedDoc.id)
                  .update({
                    'status': signedDoc.status.name,
                    'signers': signedDoc.signers.map((s) => s.toMap()).toList(),
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
            }
            _showSnack('Document signed');
            setState(() {});
          },
        ),
      ),
    );
  }

  void _showDocActions(DocumentModel doc, RelativeRect position) async {
    final v = await showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: 'preview', child: Text('Preview')),
        if (doc.status == DocumentStatus.pending)
          const PopupMenuItem(value: 'sign', child: Text('Sign')),
        const PopupMenuItem(value: 'share', child: Text('Share')),
        const PopupMenuItem(value: 'email', child: Text('Send via email')),
        if (doc.chatId != null)
          const PopupMenuItem(value: 'openChat', child: Text('Open in chat')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'details', child: Text('Details')),
      ],
    );
    switch (v) {
      case 'preview':
        _preview(doc);
        break;
      case 'sign':
        _openDetails(doc);
        break;
      case 'share':
        _share(doc);
        break;
      case 'email':
        _email(doc);
        break;
      case 'openChat':
        _openChat(doc.chatId!);
        break;
      case 'details':
        _openDetails(doc);
        break;
      default:
        break;
    }
  }

  void _preview(DocumentModel doc) {
    _showSnack('Preview: ${doc.title}');
  }

  Future<void> _email(DocumentModel doc) async {
    final subject = Uri.encodeComponent('Document: ${doc.title}');
    final body = Uri.encodeComponent(
      'Please review/sign this document.\n\nLink: ${doc.fileUrl}',
    );
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (!await launchUrl(uri)) {
      _showSnack('Could not open email app');
    }
  }

  void _share(DocumentModel doc) {
    _showSnack('Share sheet (stub) — add share_plus to implement');
  }

  void _openChat(String chatId) {
    _showSnack('Open chat $chatId (stub)');
  }

  void _onUploadTap() {
    _showSnack('Upload flow (stub) — connect to file picker / storage');
  }

  static String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'All';
      case _Filter.received:
        return 'Received';
      case _Filter.sent:
        return 'Sent';
      case _Filter.pending:
        return 'Pending';
      case _Filter.signed:
        return 'Signed';
      case _Filter.expiring:
        return 'Expiring';
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ---------------------- UI Pieces ----------------------

class _DocumentTile extends StatelessWidget {
  final DocumentModel doc;
  final String currentUserId;
  final VoidCallback onTap;
  final void Function(RelativeRect) onMore;

  const _DocumentTile({
    required this.doc,
    required this.currentUserId,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final statusChip = _statusChip(doc.status, context);
    final subtitle = _subtitleText(doc, currentUserId);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: _FileIcon(mime: doc.mimeType),
        title: Row(
          children: [
            Expanded(
              child: Text(
                doc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            statusChip,
          ],
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              final box = ctx.findRenderObject() as RenderBox;
              final overlay =
                  Overlay.of(ctx).context.findRenderObject() as RenderBox;
              final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
              final rect = RelativeRect.fromLTRB(
                offset.dx,
                offset.dy + box.size.height,
                overlay.size.width - offset.dx,
                overlay.size.height - offset.dy - box.size.height,
              );
              onMore(rect);
            },
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentModel doc;
  final String currentUserId;
  final VoidCallback onOpen;
  final void Function(RelativeRect) onMore;

  const _DocumentCard({
    required this.doc,
    required this.currentUserId,
    required this.onOpen,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final statusChip = _statusChip(doc.status, context);
    final subtitle = _subtitleText(doc, currentUserId);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FileIcon(mime: doc.mimeType),
                  const Spacer(),
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        final box = ctx.findRenderObject() as RenderBox;
                        final overlay =
                            Overlay.of(ctx).context.findRenderObject()
                                as RenderBox;
                        final offset = box.localToGlobal(
                          Offset.zero,
                          ancestor: overlay,
                        );
                        final rect = RelativeRect.fromLTRB(
                          offset.dx,
                          offset.dy + box.size.height,
                          overlay.size.width - offset.dx,
                          overlay.size.height - offset.dy - box.size.height,
                        );
                        onMore(rect);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                doc.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Align(alignment: Alignment.bottomLeft, child: statusChip),
            ],
          ),
        ),
      ),
    );
  }
}

String _subtitleText(DocumentModel d, String currentUserId) {
  final meOwner = d.ownerId == currentUserId;
  final who = meOwner ? 'You' : 'Received';
  final sCount = d.signers.where((s) => s.signedAt != null).length;
  final total = d.signers.length;
  return '$who • $sCount of $total signed';
}

Widget _statusChip(DocumentStatus status, BuildContext context) {
  final color = switch (status) {
    DocumentStatus.pending => Colors.amber.withOpacity(0.2),
    DocumentStatus.signed => Colors.green.withOpacity(0.2),
    DocumentStatus.declined => Colors.red.withOpacity(0.2),
    DocumentStatus.expired => Colors.grey.withOpacity(0.2),
  };
  final text = switch (status) {
    DocumentStatus.pending => 'Pending',
    DocumentStatus.signed => 'Signed',
    DocumentStatus.declined => 'Declined',
    DocumentStatus.expired => 'Expired',
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: Theme.of(context).textTheme.labelSmall),
  );
}

class _FileIcon extends StatelessWidget {
  final String mime;
  const _FileIcon({required this.mime});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    if (mime.contains('pdf')) {
      icon = Icons.picture_as_pdf_rounded;
    } else if (mime.contains('image')) {
      icon = Icons.image_rounded;
    } else if (mime.contains('word') || mime.contains('officedocument')) {
      icon = Icons.description_rounded;
    } else {
      icon = Icons.insert_drive_file_rounded;
    }
    return CircleAvatar(radius: 22, child: Icon(icon));
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUploadTap;
  const _EmptyState({required this.onUploadTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              'No documents yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Files shared in chats will appear here automatically.\nYou can also upload or create from a template.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onUploadTap,
              icon: const Icon(Icons.upload),
              label: const Text('Upload document'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- Detail + Sign Flow ----------------------

class _DocumentDetailScreen extends StatefulWidget {
  final DocumentModel doc;
  final String currentUserId;
  final ValueChanged<DocumentModel> onSignComplete;
  const _DocumentDetailScreen({
    required this.doc,
    required this.currentUserId,
    required this.onSignComplete,
  });

  @override
  State<_DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<_DocumentDetailScreen> {
  late DocumentModel doc;

  @override
  void initState() {
    super.initState();
    doc = widget.doc;
  }

  bool get _iAmSigner => doc.signers.any((s) => s.uid == widget.currentUserId);

  bool get _iAlreadySigned => doc.signers.any(
    (s) => s.uid == widget.currentUserId && s.signedAt != null,
  );

  Future<void> _handleSignDrawn() async {
    final bytes = await showModalBottomSheet<Uint8List?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _SignatureSheet(),
    );

    if (bytes == null) return;
    _applySignature();
  }

  Future<void> _handleSignFromLibrary() async {
    final chosen = await showModalBottomSheet<_SavedSignature?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _PickSavedSignatureSheet(),
    );
    if (chosen == null) return;
    _applySignature();
  }

  void _applySignature() {
    final now = DateTime.now();
    final updatedSigners = doc.signers.map((s) {
      if (s.uid == widget.currentUserId) {
        return s.copyWith(signedAt: now);
      }
      return s;
    }).toList();

    final allSigned = updatedSigners.every((s) => s.signedAt != null);
    setState(() {
      doc = doc.copyWith(
        signers: updatedSigners,
        status: allSigned ? DocumentStatus.signed : DocumentStatus.pending,
        updatedAt: now,
      );
    });

    widget.onSignComplete(doc);
  }

  @override
  Widget build(BuildContext context) {
    final sCount = doc.signers.where((s) => s.signedAt != null).length;
    final total = doc.signers.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.title),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => _fakeShare(),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Email',
            onPressed: () => _fakeEmail(),
            icon: const Icon(Icons.alternate_email_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Preview stub
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FileIcon(mime: doc.mimeType),
                  const SizedBox(height: 8),
                  Text(
                    'Preview not implemented',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status row
          Row(
            children: [
              _statusChip(doc.status, context),
              const SizedBox(width: 12),
              Text(
                '$sCount / $total signed',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (doc.dueAt != null)
                Text(
                  'Due: ${_fmtDate(doc.dueAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Signers
          Text('Signers', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...doc.signers.map((s) {
            final done = s.signedAt != null;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(s.name.isNotEmpty ? s.name[0] : '?'),
              ),
              title: Text(s.name),
              subtitle: Text(s.email),
              trailing: done
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(_fmtDateTime(s.signedAt!)),
                      ],
                    )
                  : const Text('Awaiting'),
            );
          }),

          const SizedBox(height: 20),

          if (_iAmSigner && !_iAlreadySigned) ...[
            FilledButton.icon(
              onPressed: _handleSignDrawn,
              icon: const Icon(Icons.draw_rounded),
              label: const Text('Sign now (draw)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _handleSignFromLibrary,
              icon: const Icon(Icons.border_color_rounded),
              label: const Text('Use a saved signature'),
            ),
          ] else if (_iAlreadySigned)
            const Text(
              'You have signed this document.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  void _fakeShare() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share (stub)')));
  }

  void _fakeEmail() async {
    final subject = Uri.encodeComponent('Document: ${doc.title}');
    final body = Uri.encodeComponent(
      'Please review/sign.\n\nLink: ${doc.fileUrl}',
    );
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    await launchUrl(uri);
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ---------------------- Signature Capture Sheet ----------------------

class _SignatureSheet extends StatefulWidget {
  const _SignatureSheet();

  @override
  State<_SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<_SignatureSheet> {
  final _points = <Offset?>[];
  final _repaintKey = GlobalKey();
  final _labelCtrl = TextEditingController();
  bool _saveToLibrary = true;

  Future<Uint8List?> _export() async {
    final boundary =
        _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveIfNeeded(Uint8List bytes) async {
    if (!_saveToLibrary) return;
    final label = _labelCtrl.text.trim().isEmpty
        ? 'Signature ${DateTime.now().millisecondsSinceEpoch}'
        : _labelCtrl.text.trim();
    await SignatureStore.addSignature(bytes: bytes, label: label);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add your signature',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AspectRatio(
                  aspectRatio: 3.0,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          RenderBox box =
                              context.findRenderObject() as RenderBox;
                          setState(() {
                            _points.add(box.globalToLocal(d.globalPosition));
                          });
                        },
                        onPanEnd: (_) => setState(() => _points.add(null)),
                        child: CustomPaint(
                          painter: _SignaturePainter(_points),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _labelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Save as (optional)',
                          hintText: 'e.g., Zah primary',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        const Text('Save'),
                        Switch(
                          value: _saveToLibrary,
                          onChanged: (v) => setState(() => _saveToLibrary = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _points.clear()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final bytes = await _export();
                      if (bytes == null) return;
                      await _saveIfNeeded(bytes);
                      if (!context.mounted) return;
                      Navigator.of(context).pop(bytes);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use signature'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.5
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset? last;
    for (final p in points) {
      if (p == null) {
        last = null;
      } else {
        if (last != null) {
          canvas.drawLine(last!, p, paint);
        }
        last = p;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}

// ---------------------- Signature Library (local) ----------------------

class _SavedSignature {
  final String id;
  final String label;
  final String dataBase64; // PNG bytes as base64
  _SavedSignature({
    required this.id,
    required this.label,
    required this.dataBase64,
  });

  Uint8List get bytes => base64Decode(dataBase64);

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'data': dataBase64,
  };

  static _SavedSignature fromMap(Map<String, dynamic> m) => _SavedSignature(
    id: m['id'] as String,
    label: m['label'] as String? ?? 'Signature',
    dataBase64: m['data'] as String,
  );
}

class SignatureStore {
  static const _key = 'saved_signatures';

  static Future<List<_SavedSignature>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final list = <_SavedSignature>[];
    for (final s in raw) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        list.add(_SavedSignature.fromMap(m));
      } catch (_) {}
    }
    return list;
  }

  static Future<void> _save(List<_SavedSignature> all) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = all.map((s) => jsonEncode(s.toMap())).toList();
    await prefs.setStringList(_key, raw);
  }

  static Future<void> addSignature({
    required Uint8List bytes,
    required String label,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final all = await load();
    all.insert(
      0,
      _SavedSignature(id: id, label: label, dataBase64: base64Encode(bytes)),
    );
    await _save(all);
  }

  static Future<void> deleteById(String id) async {
    final all = await load();
    all.removeWhere((e) => e.id == id);
    await _save(all);
  }
}

// -------------- Manage Signatures Screen --------------

class _ManageSignaturesScreen extends StatefulWidget {
  const _ManageSignaturesScreen();

  @override
  State<_ManageSignaturesScreen> createState() =>
      _ManageSignaturesScreenState();
}

class _ManageSignaturesScreenState extends State<_ManageSignaturesScreen> {
  List<_SavedSignature> _signatures = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final all = await SignatureStore.load();
    if (!mounted) return;
    setState(() => _signatures = all);
  }

  Future<void> _addNew() async {
    final bytes = await showModalBottomSheet<Uint8List?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SignatureSheet(),
    );
    // _SignatureSheet already saved if toggle was on; we just refresh.
    await _refresh();
    if (bytes != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signature added')));
    }
  }

  Future<void> _delete(String id) async {
    await SignatureStore.deleteById(id);
    await _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Signature deleted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Signatures'),
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: _addNew,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _signatures.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.border_color_rounded, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'No saved signatures',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text('Tap the + icon to create one.'),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemCount: _signatures.length,
              itemBuilder: (_, i) {
                final s = _signatures[i];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onLongPress: () => _delete(s.id),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Center(
                                child: Image.memory(
                                  s.bytes,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          TextButton.icon(
                            onPressed: () => _delete(s.id),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.draw_rounded),
        label: const Text('New'),
      ),
    );
  }
}

// ----- Picker bottom sheet to choose a saved signature -----

class _PickSavedSignatureSheet extends StatefulWidget {
  const _PickSavedSignatureSheet();

  @override
  State<_PickSavedSignatureSheet> createState() =>
      _PickSavedSignatureSheetState();
}

class _PickSavedSignatureSheetState extends State<_PickSavedSignatureSheet> {
  List<_SavedSignature> _signatures = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await SignatureStore.load();
    if (!mounted) return;
    setState(() => _signatures = all);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 360,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose a saved signature',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _signatures.isEmpty
                  ? const Center(child: Text('No saved signatures'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _signatures.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = _signatures[i];
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(s),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(s.bytes, width: 48, height: 32),
                          ),
                          title: Text(s.label),
                          trailing: const Icon(Icons.chevron_right),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- Mock Data ----------------------

List<DocumentModel> _mockDocs(String currentUserId) {
  final other = 'user_B';
  return [
    DocumentModel(
      id: 'd1',
      title: 'NDA - Project Aurora',
      fileUrl: 'https://example.com/nda.pdf',
      mimeType: 'application/pdf',
      ownerId: currentUserId,
      participants: [currentUserId, other],
      tags: ['NDA', 'Aurora'],
      status: DocumentStatus.pending,
      signers: [
        DocumentSigner(
          uid: currentUserId,
          name: 'You',
          email: 'you@openbook.com',
          order: 1,
          signedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        DocumentSigner(
          uid: other,
          name: 'Liam Wong',
          email: 'liam@example.com',
          order: 2,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      dueAt: DateTime.now().add(const Duration(days: 4)),
      sizeBytes: 120043,
      chatId: 'chat_aurora',
    ),
    DocumentModel(
      id: 'd2',
      title: 'Service Agreement - Immersive Soundz',
      fileUrl: 'https://example.com/service.pdf',
      mimeType: 'application/pdf',
      ownerId: other,
      participants: [currentUserId, other],
      tags: ['Contract'],
      status: DocumentStatus.signed,
      signers: [
        DocumentSigner(
          uid: currentUserId,
          name: 'You',
          email: 'you@openbook.com',
          order: 1,
          signedAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
        DocumentSigner(
          uid: other,
          name: 'Sumitra Nathan',
          email: 'sumitra@example.com',
          order: 2,
          signedAt: DateTime.now().subtract(const Duration(days: 6)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      dueAt: null,
      sizeBytes: 340210,
      chatId: 'chat_service',
    ),
    DocumentModel(
      id: 'd3',
      title: 'Invoice #1045',
      fileUrl: 'https://example.com/invoice_1045.pdf',
      mimeType: 'application/pdf',
      ownerId: currentUserId,
      participants: [currentUserId, other],
      tags: ['Invoice', 'Finance'],
      status: DocumentStatus.expired,
      signers: [
        DocumentSigner(
          uid: currentUserId,
          name: 'You',
          email: 'you@openbook.com',
          order: 1,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 20)),
      dueAt: DateTime.now().subtract(const Duration(days: 1)),
      sizeBytes: 88500,
      chatId: null,
    ),
  ];
}
