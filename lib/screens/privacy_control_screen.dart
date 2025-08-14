import 'package:flutter/material.dart';

class PrivacyControlScreen extends StatefulWidget {
  const PrivacyControlScreen({super.key});

  @override
  State<PrivacyControlScreen> createState() => _PrivacyControlScreenState();
}

class _PrivacyControlScreenState extends State<PrivacyControlScreen> {
  bool _vaultMode = false; // visual only
  bool _dataLockLocalOnly = false; // visual only
  bool _analyticsOff = true; // visual only

  // Mock access history (visual only)
  final List<_AccessEvent> _history = const [
    _AccessEvent("You", "iPhone 15 Pro", "Today • 2:35 PM", "Viewed document"),
    _AccessEvent("You", "Web App", "Yesterday • 9:17 PM", "Synced photos"),
    _AccessEvent(
      "You",
      "Android Tablet",
      "Aug 06 • 4:02 PM",
      "Downloaded backup",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Dashboard"),
        // Match Home's Hero so the shield animates cleanly
        leading: Hero(
          tag: 'privacy_shield',
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.shield_outlined),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Privacy policy (coming soon)",
            onPressed: () => _toast(context, "Privacy Policy coming soon"),
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // STATUS
            _Card(
              child: Row(
                children: [
                  _Shield(
                    statusOn: _vaultMode || _analyticsOff || _dataLockLocalOnly,
                  ),
                  const SizedBox(width: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _vaultMode
                          ? "Vault Mode is ON — minimal sync. No behavior tracking."
                          : _dataLockLocalOnly
                          ? "Local-Only is ON — new content stays on this device."
                          : _analyticsOff
                          ? "Analytics OFF — essentials only. No ad tracking."
                          : "Private by default — we don’t mine or sell your data.",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // TOGGLES
            _Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _vaultMode,
                    onChanged: (v) => setState(() => _vaultMode = v),
                    title: const Text("Vault Mode"),
                    subtitle: const Text(
                      "Minimal cloud sync. No behavior tracking.",
                    ),
                    secondary: const Icon(Icons.lock_person_outlined),
                  ),
                  const Divider(height: 0),
                  SwitchListTile(
                    value: _dataLockLocalOnly,
                    onChanged: (v) => setState(() => _dataLockLocalOnly = v),
                    title: const Text("Data Lock (local-only)"),
                    subtitle: const Text(
                      "New content stays on this device only.",
                    ),
                    secondary: const Icon(Icons.phonelink_lock_outlined),
                  ),
                  const Divider(height: 0),
                  SwitchListTile(
                    value: _analyticsOff,
                    onChanged: (v) => setState(() => _analyticsOff = v),
                    title: const Text("Turn off analytics"),
                    subtitle: const Text("No ad tracking. Essentials only."),
                    secondary: const Icon(Icons.insights_outlined),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ENCRYPTION INFO
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    icon: Icons.vpn_key_outlined,
                    title: "End-to-End Encryption",
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your private files are encrypted before they leave your device. Only your keys can decrypt them.",
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _Pill(text: "Keys stored on device"),
                      _Pill(text: "Zero-knowledge server"),
                      _Pill(text: "Owner-only access"),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _toast(context, "Key backup coming soon"),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text("Backup my key"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _toast(context, "Key recovery coming soon"),
                        icon: const Icon(Icons.vpn_key_outlined),
                        label: const Text("Recover key"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ACCESS HISTORY
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    icon: Icons.history_outlined,
                    title: "Access history",
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text("No accesses in the last 30 days."),
                    )
                  else
                    ..._history.map(
                      (e) => Column(
                        children: [
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: cs.surfaceVariant,
                              child: const Icon(Icons.person_outline),
                            ),
                            title: Text("${e.actor} • ${e.device}"),
                            subtitle: Text("${e.when} • ${e.action}"),
                          ),
                          if (e != _history.last) const Divider(height: 0),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // YOUR DATA ACTIONS
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    icon: Icons.file_download_outlined,
                    title: "Your data",
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "You own your content. Download or delete anytime.",
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            _toast(context, "Preparing export (visual only)"),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text("Export my data"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _toast(
                          context,
                          "Deletion request flow (visual only)",
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Request data deletion"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // PRIVACY PLANS (monetization)
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SectionTitle(
                    icon: Icons.workspace_premium_outlined,
                    title: "Privacy plans",
                  ),
                  SizedBox(height: 8),
                  _PlansWrap(), // stacked, full width
                ],
              ),
            ),

            const SizedBox(height: 12),

            // PRIVACY PROMISE
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    icon: Icons.verified_user_outlined,
                    title: "Our privacy promise",
                  ),
                  const SizedBox(height: 8),
                  const _Bullet(text: "We do not mine or sell your data."),
                  const _Bullet(text: "You own your content — always."),
                  const _Bullet(
                    text: "End-to-end encryption for private data.",
                  ),
                  const _Bullet(
                    text: "Only you hold the keys (zero-knowledge).",
                  ),
                  const _Bullet(text: "Independent audit commitment."),
                  const SizedBox(height: 12),
                  Text(
                    "How we make money: subscriptions for advanced privacy (Vault Mode, local-only at scale, self-managed keys). Your privacy is not the product.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* ---------- helpers ---------- */

class _AccessEvent {
  final String actor;
  final String device;
  final String when;
  final String action;
  const _AccessEvent(this.actor, this.device, this.when, this.action);
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: .2,
    );
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Text(title, style: style),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("•  "),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Shield extends StatefulWidget {
  final bool statusOn;
  const _Shield({required this.statusOn});

  @override
  State<_Shield> createState() => _ShieldState();
}

class _ShieldState extends State<_Shield> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final pulse = widget.statusOn ? (1 + (_ctrl.value * 0.06)) : 1.0;
        return Transform.scale(
          scale: pulse,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.statusOn)
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(.35),
                        blurRadius: 22,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.statusOn
                        ? [cs.primary, cs.primary.withOpacity(.6)]
                        : [cs.tertiary, cs.tertiary.withOpacity(.6)],
                  ),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ---------- plans (monetization) ---------- */

class _PlansWrap extends StatelessWidget {
  const _PlansWrap();

  @override
  Widget build(BuildContext context) {
    // Stack plans vertically and stretch full width
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanCard(
          name: "Free",
          price: "AED 0",
          period: "/forever",
          highlight: false,
          features: const [
            "End-to-end encryption",
            "Private messages & files",
            "No data selling or mining",
          ],
          ctaLabel: "Included",
        ),
        const SizedBox(height: 14),
        _PlanCard(
          name: "Plus",
          price: "AED 19",
          period: "/mo",
          highlight: true,
          badge: "Most popular",
          features: const [
            "Encrypted Media Vault (10 GB)",
            "Disappearing messages",
            "Vault Mode & Local-Only toggle",
          ],
          ctaLabel: "Upgrade",
        ),
        const SizedBox(height: 14),
        _PlanCard(
          name: "Pro",
          price: "AED 39",
          period: "/mo",
          highlight: false,
          features: const [
            "Self-managed keys",
            "Metadata minimization",
            "Geo-lock & advanced controls",
          ],
          ctaLabel: "Go Pro",
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String period;
  final bool highlight;
  final String? badge;
  final List<String> features;
  final String ctaLabel;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.ctaLabel,
    this.highlight = false,
    this.badge,
  });

  // vibrant palette per tier (Dart 2/3 safe)
  List<Color> _palette() {
    final n = name.toLowerCase();
    if (n.contains('pro')) {
      // gold/orange
      return const [Color(0xFFFFB300), Color(0xFFFF7043), Color(0xFFFFA000)];
    } else if (n.contains('plus')) {
      // indigo/purple
      return const [Color(0xFF7C4DFF), Color(0xFF536DFE), Color(0xFF5C6BC0)];
    }
    // free: teal/cyan
    return const [Color(0xFF26A69A), Color(0xFF26C6DA), Color(0xFF26A69A)];
  }

  IconData _iconForPlan() {
    final n = name.toLowerCase();
    if (n.contains('pro')) return Icons.workspace_premium_outlined;
    if (n.contains('plus')) return Icons.bolt_outlined;
    return Icons.shield_outlined;
  }

  @override
  Widget build(BuildContext context) {
    const double kMinHeight = 240; // unify heights
    final theme = Theme.of(context);

    final pal = _palette();
    final c1 = pal[0];
    final c2 = pal[1];
    final accent = pal[2];

    final headerGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c1, c2],
    );

    // show up to 3 features for consistent card height
    final shown = features.take(3).toList();
    final moreCount = features.length - shown.length;

    final bodyColor = theme.colorScheme.surface;
    final textColor = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(.92)
        : Colors.black.withOpacity(.84);

    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinHeight),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c1.withOpacity(.18),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: c1.withOpacity(.45), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // gradient header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(gradient: headerGrad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(.18),
                        ),
                        child: Icon(
                          _iconForPlan(),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: price,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                            TextSpan(
                              text: ' $period',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // badge strip (optional)
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: c1.withOpacity(.08)),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: c1,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: .2,
                      ),
                    ),
                  ),

                // body
                Container(
                  color: bodyColor,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...shown.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (moreCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '+ $moreCount more…',
                          style: TextStyle(
                            color: textColor.withOpacity(.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // CTA
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "$name plan selected (visual only)",
                                ),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: c1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.lock_open_outlined),
                          label: Text(
                            ctaLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
