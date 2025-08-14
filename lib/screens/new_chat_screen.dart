import 'package:flutter/material.dart';

class NewChatScreen extends StatefulWidget {
  final List<NCContact> contacts;
  final List<NCContact>? recentlyContacted;
  final NCContact? self;
  final VoidCallback? onNewGroup;
  final VoidCallback? onNewContact;
  final ValueChanged<NCContact>? onSelectContact;
  final VoidCallback? onMessageYourself;

  const NewChatScreen({
    super.key,
    this.contacts = const [],
    this.recentlyContacted,
    this.self,
    this.onNewGroup,
    this.onNewContact,
    this.onSelectContact,
    this.onMessageYourself,
  });

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _search = TextEditingController();
  final List<String> _alphabet = List.generate(
    26,
    (i) => String.fromCharCode(65 + i),
  );

  // Data (with demo fallbacks so it looks full immediately)
  late List<NCContact> _all;
  late List<NCContact> _recent;
  NCContact? _self;

  // Grouping + anchors
  final Map<String, List<NCContact>> _grouped = {};
  final Map<String, GlobalKey> _anchors = {};

  String _query = '';

  @override
  void initState() {
    super.initState();
    _seedData();
    _rebuildGroups();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
  }

  @override
  void didUpdateWidget(covariant NewChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _seedData();
    _rebuildGroups();
  }

  void _seedData() {
    _all = widget.contacts.isNotEmpty ? widget.contacts : _demoContacts;
    _recent = (widget.recentlyContacted?.isNotEmpty ?? false)
        ? widget.recentlyContacted!
        : _demoRecent;
    _self = widget.self ?? _demoSelf;
  }

  void _rebuildGroups() {
    _grouped.clear();
    _anchors.clear();
    for (final l in _alphabet) {
      _grouped[l] = [];
      _anchors[l] = GlobalKey();
    }
    final src = _filtered(_all);
    for (final c in src) {
      final ch = (c.name.isNotEmpty ? c.name[0] : '#').toUpperCase();
      final bucket = _alphabet.contains(ch) ? ch : _alphabet.first;
      _grouped[bucket]!.add(c);
    }
    for (final l in _alphabet) {
      _grouped[l]!.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  List<NCContact> _filtered(List<NCContact> list) {
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.subtitle ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  // A–Z rail jumps
  void _jumpTo(String letter) {
    final ctx = _anchors[letter]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
  }

  void _dragJump(Offset globalPos, BuildContext barCtx) {
    final box = barCtx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final perItem = 16.0;
    final idx = (local.dy ~/ perItem).clamp(0, _alphabet.length - 1);
    _jumpTo(_alphabet[idx]);
  }

  @override
  Widget build(BuildContext context) {
    _rebuildGroups(); // keep headers in sync with filter

    final theme = Theme.of(context);
    final railBg = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.04);

    return Scaffold(
      appBar: AppBar(title: const Text('New chat'), centerTitle: true),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _searchBar(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _quickActionsCard(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (_query.isEmpty && _recent.isNotEmpty) ...[
                _stickyHeader(context, 'Recently contacted'),
                SliverToBoxAdapter(
                  child: _sectionCard(
                    children: _filtered(_recent)
                        .map(
                          (c) => _tileWithDivider(
                            context,
                            _contactTile(context, c),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              if (_query.isEmpty && _self != null) ...[
                _stickyHeader(context, 'Message yourself'),
                SliverToBoxAdapter(
                  child: _sectionCard(
                    children: [
                      _tileWithDivider(
                        context,
                        _contactTile(
                          context,
                          _self!,
                          leadingOverride: CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                theme.colorScheme.primary.withOpacity(0.12),
                            child: Icon(
                              Icons.person,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          subtitleOverride: 'Save notes, links, & media',
                          onTap: () {
                            widget.onMessageYourself?.call();
                            Navigator.pop(context, _self);
                          },
                        ),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // A–Z groups with sticky headers & section cards
              ..._alphabet.expand((l) {
                final items = _grouped[l]!;
                if (items.isEmpty) return <Widget>[];
                return [
                  _stickyHeader(context, l, anchorKey: _anchors[l]),
                  SliverToBoxAdapter(
                    child: _sectionCard(
                      children: items
                          .asMap()
                          .entries
                          .map(
                            (e) => _tileWithDivider(
                              context,
                              _contactTile(context, e.value),
                              showDivider: e.key != items.length - 1,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ];
              }),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),

          // A–Z rail
          Positioned(
            right: 0,
            top: 8,
            bottom: 8,
            child: LayoutBuilder(
              builder: (ctx, _) {
                return GestureDetector(
                  onTapDown: (d) => _dragJump(d.globalPosition, ctx),
                  onPanStart: (d) => _dragJump(d.globalPosition, ctx),
                  onPanUpdate: (d) => _dragJump(d.globalPosition, ctx),
                  child: Container(
                    width: 28,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: railBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _alphabet
                          .map(
                            (l) => Expanded(
                              child: Center(
                                child: Text(
                                  l,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================== UI bits ==================

  Widget _searchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search name or number',
                border: InputBorder.none,
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _search.clear();
                FocusScope.of(context).unfocus();
              },
            ),
        ],
      ),
    );
  }

  Widget _quickActionsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Column(
        children: [
          _quickActionTile(
            context,
            icon: Icons.group_add_outlined,
            title: 'New group',
            onTap: () => widget.onNewGroup?.call(),
          ),
          const Divider(height: 1),
          _quickActionTile(
            context,
            icon: Icons.person_add_alt_1_outlined,
            title: 'New contact',
            onTap: () => widget.onNewContact?.call(),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(radius: 20, child: Icon(icon)),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  // Sticky header for sections
  Widget _stickyHeader(
    BuildContext context,
    String title, {
    GlobalKey? anchorKey,
  }) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SectionHeaderDelegate(
        keyWidget: anchorKey == null ? null : KeyWidget(key: anchorKey),
        title: title,
        background: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }

  // Rounded section container
  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // Tile with optional divider for neat section blocks
  Widget _tileWithDivider(
    BuildContext context,
    Widget tile, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        tile,
        if (showDivider)
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.25),
          ),
      ],
    );
  }

  Widget _alphaHeader(BuildContext context, String letter) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  Widget _contactTile(
    BuildContext context,
    NCContact c, {
    Widget? leadingOverride,
    String? subtitleOverride,
    bool trailingChevron = false,
    VoidCallback? onTap,
  }) {
    final imgProvider = _imageProvider(c.photoUrl);
    final trailing =
        trailingChevron ? const Icon(Icons.chevron_right, size: 18) : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: leadingOverride ??
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: imgProvider,
                child: imgProvider == null
                    ? Text(
                        _initials(c.name),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              if (c.isOnline != null)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: c.isOnline! ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
      title: Text(c.name),
      subtitle: Text(
        subtitleOverride ?? (c.subtitle ?? ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
      onTap: onTap ??
          () {
            widget.onSelectContact?.call(c);
            Navigator.pop(context, c); // return selected contact
          },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // Helpers
  ImageProvider<Object>? _imageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('assets/')) {
      return AssetImage(url) as ImageProvider<Object>;
    } else {
      return NetworkImage(url) as ImageProvider<Object>;
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // Demo fallback so the screen looks rich without data
  List<NCContact> get _demoContacts => const [
        NCContact(id: '1', name: 'Amelia Collins'),
        NCContact(id: '2', name: 'Ava Mitchell'),
        NCContact(id: '3', name: 'Charlotte Brooks'),
        NCContact(id: '4', name: 'Daniel Reed'),
        NCContact(id: '5', name: 'Emma Carter'),
        NCContact(id: '6', name: 'Fatima Ali'),
        NCContact(id: '7', name: 'George Tan'),
        NCContact(id: '8', name: 'Hannah Lee'),
        NCContact(id: '9', name: 'Isla Khan'),
        NCContact(id: '10', name: 'Jack Morgan'),
        NCContact(id: '11', name: 'Khalid Rahman'),
        NCContact(id: '12', name: 'Liam Wong'),
        NCContact(id: '13', name: 'Maya Patel'),
        NCContact(id: '14', name: 'Noah Zhang'),
        NCContact(id: '15', name: 'Olivia Costa'),
        NCContact(id: '16', name: 'Priya Sharma'),
        NCContact(id: '17', name: 'Quinn Rivera'),
        NCContact(id: '18', name: 'Rohan Gupta'),
        NCContact(id: '19', name: 'Sara Haddad'),
        NCContact(id: '20', name: 'Tariq Hassan'),
        NCContact(id: '21', name: 'Ursula Green'),
        NCContact(id: '22', name: 'Victor Chen'),
        NCContact(id: '23', name: 'Willow James'),
        NCContact(id: '24', name: 'Xander Cole'),
        NCContact(id: '25', name: 'Yara Suleiman'),
        NCContact(id: '26', name: 'Zoe Martins'),
      ];

  List<NCContact> get _demoRecent => const [
        NCContact(id: '2', name: 'Ava Mitchell', subtitle: 'Online'),
        NCContact(id: '12', name: 'Liam Wong', subtitle: 'Last seen recently'),
        NCContact(id: '19', name: 'Sara Haddad', subtitle: 'Busy'),
      ];

  NCContact get _demoSelf =>
      const NCContact(id: 'me', name: 'You', subtitle: 'Message yourself');
}

// Sticky header delegate
class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final KeyWidget? keyWidget; // invisible anchor for A–Z jumps
  final String title;
  final Color background;

  _SectionHeaderDelegate({
    required this.title,
    required this.background,
    this.keyWidget,
  });

  @override
  double get minExtent => 34;
  @override
  double get maxExtent => 34;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      color: background,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const SizedBox(width: 16),
          if (keyWidget != null) keyWidget!,
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return title != oldDelegate.title || background != oldDelegate.background;
  }
}

// Tiny widget just to carry a GlobalKey as an anchor (takes no space)
class KeyWidget extends StatelessWidget {
  const KeyWidget({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// Screen model
class NCContact {
  final String id;
  final String name;
  final String? subtitle;
  final String? photoUrl;
  final bool? isOnline;
  const NCContact({
    required this.id,
    required this.name,
    this.subtitle,
    this.photoUrl,
    this.isOnline,
  });
}
