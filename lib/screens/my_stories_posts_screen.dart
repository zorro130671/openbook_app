import 'dart:math';
import 'package:flutter/material.dart';

/// Full rewrite of the Stories & Posts screen with:
/// - Stories bar
/// - Toggle between feed and grid
/// - Grid tiles (image-only) -> opens viewer
/// - Feed cards -> opens same viewer
/// - Photo viewer: caption/likes/comments BELOW the photo
/// - Crispy 3D-ish heart pop + confetti (no external packages)
/// - Lightweight bottom nav (placeholder routing)

class MyStoriesPostsScreen extends StatefulWidget {
  const MyStoriesPostsScreen({super.key});

  @override
  State<MyStoriesPostsScreen> createState() => _MyStoriesPostsScreenState();
}

/* ===================== Data Models ===================== */

class _Comment {
  final String user;
  final String avatarUrl;
  final String time; // e.g. "5m", "2h", "1d"
  final String text;
  const _Comment({
    required this.user,
    required this.avatarUrl,
    required this.time,
    required this.text,
  });
}

class _Post {
  final String id;
  final String author;
  final String time;
  final String text;
  final String imageUrl;
  int likes;
  final List<_Comment> commentsList;

  _Post({
    required this.id,
    required this.author,
    required this.time,
    required this.text,
    required this.imageUrl,
    this.likes = 0,
    this.commentsList = const [],
  });
}

/* ===================== Confetti (no packages) ===================== */

class _Particle {
  // initial origin = screen center
  final double vx; // px/ms relative
  final double vy;
  final double angVel; // angular velocity
  final Color color;
  final double size;
  final double startAngle;

  _Particle({
    required this.vx,
    required this.vy,
    required this.angVel,
    required this.color,
    required this.size,
    required this.startAngle,
  });

  factory _Particle.random() {
    final rnd = Random();
    // throw in an upward cone
    final theta = (-pi / 2) + (rnd.nextDouble() - 0.5) * (pi / 1.2);
    final speed = 0.7 + rnd.nextDouble() * 1.6; // relative
    final vx = speed * cos(theta);
    final vy = speed * sin(theta);
    final angVel = (rnd.nextDouble() - 0.5) * 8;
    final size = 4 + rnd.nextDouble() * 6;
    final palette = [
      Colors.pinkAccent,
      Colors.amber,
      Colors.lightBlueAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
    ];
    return _Particle(
      vx: vx,
      vy: vy,
      angVel: angVel,
      color: palette[rnd.nextInt(palette.length)],
      size: size,
      startAngle: rnd.nextDouble() * 2 * pi,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress; // 0..1
  final List<_Particle> particles;
  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final t = progress;
    const g = 1800.0; // gravity feel
    for (final p in particles) {
      final time = t * 1.2;
      final dx = p.vx * 800 * time;
      final dy = p.vy * 800 * time + 0.5 * g * time * time * 0.001;
      final pos = origin.translate(dx, dy);
      final paint = Paint()..color = p.color.withOpacity((1 - t).clamp(0, 1));
      final angle = p.startAngle + p.angVel * time;
      final rect = Rect.fromCenter(
        center: pos,
        width: p.size,
        height: p.size * 1.6,
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      canvas.translate(-pos.dx, -pos.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress || old.particles != particles;
}

/* ===================== Heart Pop (3D-ish) ===================== */

// 3D-ish heart with glow + drop shadow
class _PopHeart extends StatelessWidget {
  final Animation<double> scale;
  const _PopHeart({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: scale,
        builder: (_, __) {
          final s = scale.value;
          final tilt = (s - 1.0) * 0.15; // subtle tilt

          return Transform.rotate(
            angle: tilt,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // soft white glow behind
                Opacity(
                  opacity: 0.25 + 0.35 * (s - 0.8).clamp(0, 1),
                  child: Transform.scale(
                    scale: s * 1.2,
                    child: const Icon(
                      Icons.favorite,
                      size: 160,
                      color: Colors.white,
                    ),
                  ),
                ),
                // drop shadow under heart
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.45,
                        child: Container(
                          width: 120 * s,
                          height: 120 * s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.45),
                                blurRadius: 28,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // main red heart
                Transform.scale(
                  scale: s,
                  child: const Icon(
                    Icons.favorite,
                    size: 140,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ===================== Screen State ===================== */

class _MyStoriesPostsScreenState extends State<MyStoriesPostsScreen> {
  bool _gridMode = false;
  int _tabIndex = 1; // 0=Home, 1=Stories, 2=Chats, 3=Profile

  // Generate realistic mock comments per post id
  List<_Comment> _genComments(String id) {
    const names = [
      'Ava',
      'Liam',
      'Noah',
      'Olivia',
      'Mia',
      'Ethan',
      'Zoe',
      'Lucas',
      'Ivy',
      'Aria',
      'Ben',
      'Chloe',
      'Leo',
      'Maya',
      'Nora',
      'Kai',
      'Ella',
      'Iris',
      'Eli',
      'Ruby',
    ];
    const lines = [
      '🔥 Love this!',
      'So clean 👏',
      'This goes hard.',
      'Where is this? 😍',
      'A whole vibe!',
      'Saved for later.',
      'Insane shot!',
      'Teach me your ways!',
      'Underrated post tbh',
      'This is chef’s kiss',
    ];
    final count = 6 + (id.hashCode.abs() % 7); // 6..12
    return List<_Comment>.generate(count, (j) {
      final face = 5 + ((id.hashCode + j) % 60); // 5..64
      final when = (j % 3 == 0)
          ? '${j + 1}m'
          : (j % 3 == 1)
          ? '${j + 1}h'
          : '${j + 1}d';
      return _Comment(
        user: names[(id.hashCode + j) % names.length],
        avatarUrl: 'https://i.pravatar.cc/150?img=$face',
        time: when,
        text: lines[(id.hashCode + j) % lines.length],
      );
    });
  }

  // Realistic sample posts
  late final List<_Post> _posts = [
    _Post(
      id: 'p1',
      author: 'You',
      time: '2m ago',
      text: 'Sunset vibes 🌅 Loving this view.',
      imageUrl: 'https://picsum.photos/id/1018/900/900',
      likes: 128,
      commentsList: _genComments('p1'),
    ),
    _Post(
      id: 'p2',
      author: 'You',
      time: '5m ago',
      text: 'Morning coffee ☕ + fresh air 🌿',
      imageUrl: 'https://picsum.photos/id/1025/900/900',
      likes: 92,
      commentsList: _genComments('p2'),
    ),
    _Post(
      id: 'p3',
      author: 'You',
      time: '1h ago',
      text: 'Beach walk therapy 🏖️',
      imageUrl: 'https://picsum.photos/id/1003/900/900',
      likes: 210,
      commentsList: _genComments('p3'),
    ),
    _Post(
      id: 'p4',
      author: 'You',
      time: '2h ago',
      text: 'New artwork in progress 🎨',
      imageUrl: 'https://picsum.photos/id/1020/900/900',
      likes: 76,
      commentsList: _genComments('p4'),
    ),
    _Post(
      id: 'p5',
      author: 'You',
      time: '3h ago',
      text: 'Hiking the mountain trails ⛰️',
      imageUrl: 'https://picsum.photos/id/1040/900/900',
      likes: 184,
      commentsList: _genComments('p5'),
    ),
    _Post(
      id: 'p6',
      author: 'You',
      time: '6h ago',
      text: 'City lights at night ✨',
      imageUrl: 'https://picsum.photos/id/1031/900/900',
      likes: 153,
      commentsList: _genComments('p6'),
    ),
    for (int i = 7; i <= 18; i++)
      _Post(
        id: 'p$i',
        author: i % 2 == 0 ? 'Friend ${i % 7 + 1}' : 'You',
        time: '${i}m ago',
        text: [
          'Cozy corner reading time 📚',
          'Post-workout endorphins 💪',
          'Caught the golden hour ✨',
          'Exploring new places 🗺️',
          'Weekend brunch is a must 🥞',
          'Little wins today 🙌',
          'Sky looked unreal tonight 🌌',
          'Color study for a new piece 🎨',
        ][i % 8],
        imageUrl: 'https://picsum.photos/seed/p$i/900/900',
        likes: 40 + (i * 7) % 120,
        commentsList: _genComments('p$i'),
      ),
  ];

  List<_Post> get _imagePosts => _posts;

  Future<void> _openComposer() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _ComposerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stories & Posts'),
        actions: [
          IconButton(
            tooltip: _gridMode ? 'Show list' : 'Show grid',
            icon: Icon(
              _gridMode ? Icons.view_agenda_outlined : Icons.grid_on_outlined,
            ),
            onPressed: () => setState(() => _gridMode = !_gridMode),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Stories bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _StoriesBar(
                onAddStory: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Create Story (coming soon)')),
                  );
                },
              ),
            ),
          ),

          // Grid or Feed
          if (_gridMode)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final p = _imagePosts[index];
                  final tag = 'grid_${p.id}';
                  return _GridTile(post: p, heroTag: tag);
                }, childCount: _imagePosts.length),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                return Column(
                  children: [
                    _PostCard(post: _posts[i]),
                    const SizedBox(height: 8),
                  ],
                );
              }, childCount: _posts.length),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        icon: const Icon(Icons.add),
        label: const Text('New post'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) {
          if (i == _tabIndex) return;
          setState(() => _tabIndex = i);
          // TODO: wire to real routes
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigate to tab $i (wire later)')),
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_mosaic_outlined),
            label: 'Stories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/* ===================== Stories Bar ===================== */

class _StoriesBar extends StatelessWidget {
  final VoidCallback onAddStory;
  const _StoriesBar({required this.onAddStory});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _StoryBubble(
        label: 'Your story',
        onTap: onAddStory,
        icon: Icons.add_a_photo,
        accent: Theme.of(context).colorScheme.primary,
      ),
      for (int i = 0; i < 10; i++)
        _StoryBubble(
          label: 'Friend ${i + 1}',
          onTap: () {},
          imageUrl: 'https://i.pravatar.cc/150?img=${i + 5}',
        ),
    ];

    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final String? imageUrl;
  final IconData? icon;
  final Color? accent;

  const _StoryBubble({
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = accent ?? Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [ringColor, ringColor.withOpacity(.5)],
              ),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: (imageUrl != null)
                  ? NetworkImage(imageUrl!)
                  : null,
              child: (imageUrl == null && icon != null)
                  ? Icon(icon, size: 24)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/* ===================== Feed Post Card ===================== */

class _PostCard extends StatelessWidget {
  final _Post post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(post.time, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // text
            Text(post.text),
            const SizedBox(height: 8),

            // IMAGE (tap to open viewer)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: GestureDetector(
                  onTap: () {
                    final tag = 'feed_${post.id}';
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _PhotoViewer(post: post, tag: tag),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'feed_${post.id}',
                    child: Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, p) => p == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            // actions row
            Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.favorite_border),
                ),
                Text('${post.likes}'),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                Text('${post.commentsList.length}'),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ===================== Grid Tile ===================== */

class _GridTile extends StatelessWidget {
  final _Post post;
  final String heroTag;
  const _GridTile({required this.post, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PhotoViewer(post: post, tag: heroTag),
          ),
        );
        if (result is Map) {
          // sync back likes/comments if viewer changes them
          final likes = result['likes'] as int?;
          final cmts = result['comments'] as List<_Comment>?;
          if (likes != null) post.likes = likes;
          if (cmts != null) {
            post.commentsList
              ..clear()
              ..addAll(cmts);
          }
        }
      },
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AspectRatio(
            aspectRatio: 1, // perfect square
            child: Image.network(
              post.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== Photo Viewer ===================== */

class _PhotoViewer extends StatefulWidget {
  final _Post post;
  final String tag;
  const _PhotoViewer({required this.post, required this.tag});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer>
    with TickerProviderStateMixin {
  late int _likes;
  bool _liked = false;

  // Heart pop
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;
  bool _showHeart = false;

  // Confetti
  late final AnimationController _confettiCtrl;
  static const int _confettiCount = 40;
  late final List<_Particle> _particles;

  // Local comments
  late List<_Comment> _comments;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likes;
    _comments = List<_Comment>.from(widget.post.commentsList);

    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartScale = CurvedAnimation(
      parent: _heartCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _particles = List.generate(_confettiCount, (_) => _Particle.random());
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _like({bool animateHeart = false}) {
    if (!_liked) {
      setState(() {
        _liked = true;
        _likes += 1;
      });
      if (animateHeart) _burstHeartWithConfetti();
    } else {
      setState(() {
        _liked = false;
        _likes = (_likes > 0) ? _likes - 1 : 0;
      });
    }
  }

  Future<void> _burstHeartWithConfetti() async {
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0);
    _confettiCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _showHeart = false);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final textCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .6,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text('Comments', style: Theme.of(ctx).textTheme.titleMedium),
                const Divider(height: 16),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(c.avatarUrl),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.user,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              c.time,
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(c.text),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite_border, size: 20),
                          onPressed: () {},
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Send',
                        onPressed: () {
                          final t = textCtrl.text.trim();
                          if (t.isEmpty) return;
                          setState(() {
                            _comments.add(
                              _Comment(
                                user: 'You',
                                avatarUrl: 'https://i.pravatar.cc/150?img=3',
                                time: 'now',
                                text: t,
                              ),
                            );
                          });
                          textCtrl.clear();
                        },
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IMAGE AREA — fixed aspect ratio so details sit directly under
            AspectRatio(
              aspectRatio: 1.0, // or 16/9 if you prefer widescreen
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Image
                  Center(
                    child: Hero(
                      tag: widget.tag,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Image.network(
                          post.imageUrl,
                          fit: BoxFit.contain, // stays centered
                          loadingBuilder: (c, child, p) {
                            if (p == null) return child;
                            return const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Heart animation
                  if (_showHeart) _PopHeart(scale: _heartScale),

                  // Confetti overlay
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _confettiCtrl,
                      builder: (_, __) => CustomPaint(
                        size: Size.infinite,
                        painter: _ConfettiPainter(
                          progress: _confettiCtrl.value,
                          particles: _particles,
                        ),
                      ),
                    ),
                  ),

                  // Tap/double-tap layer
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _like(animateHeart: true),
                      onTap: () => setState(() => _showHeart = !_showHeart),
                    ),
                  ),

                  // Close X
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        splashRadius: 22,
                        onPressed: () => Navigator.of(
                          context,
                        ).pop({'likes': _likes, 'comments': _comments}),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // DETAILS — directly UNDER the photo (no gap)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // author + time
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${post.author} • ${post.time}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // caption
                  Text(post.text, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),

                  // actions
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _like(),
                        icon: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? Colors.redAccent : Colors.white,
                        ),
                      ),
                      Text(
                        '$_likes',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _openComments,
                        icon: const Icon(
                          Icons.mode_comment_outlined,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_comments.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.share_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Optional: bottom nav on the viewer (mirrors main screen)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Stories tab
        onTap: (i) {
          if (i == 1) return;
          Navigator.of(context).pop({'likes': _likes, 'comments': _comments});
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_mosaic_outlined),
            label: 'Stories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/* ===================== Composer Sheet ===================== */

class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet();

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _textCtrl = TextEditingController();
  bool _shareToStory = true;
  bool _shareToFeed = true;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          TextField(
            controller: _textCtrl,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'What’s on your mind?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.photo_outlined),
                label: const Text('Photo'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Video'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.mic_none),
                label: const Text('Audio'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.poll_outlined),
                label: const Text('Poll'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _shareToStory,
            onChanged: (v) => setState(() => _shareToStory = v),
            title: const Text('Share to Story (24h)'),
          ),
          SwitchListTile(
            value: _shareToFeed,
            onChanged: (v) => setState(() => _shareToFeed = v),
            title: const Text('Share to Feed (permanent)'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post created (placeholder)')),
              );
            },
            icon: const Icon(Icons.send),
            label: const Text('Post'),
          ),
        ],
      ),
    );
  }
}
