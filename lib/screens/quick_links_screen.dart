// lib/screens/quick_links_screen.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'privacy_control_screen.dart';
import 'documents_screen.dart';

class QuickLinksScreen extends StatefulWidget {
  final bool initialTranslate;
  final String initialLang;
  final UserModel? currentUser;
  final ValueChanged<bool>? onTranslateChanged;
  final ValueChanged<String>? onLangChanged;

  const QuickLinksScreen({
    super.key,
    required this.initialTranslate,
    required this.initialLang,
    this.currentUser,
    this.onTranslateChanged,
    this.onLangChanged,
  });

  @override
  State<QuickLinksScreen> createState() => _QuickLinksScreenState();
}

class _QuickLinksScreenState extends State<QuickLinksScreen> {
  late bool _autoTranslate;
  late String _targetLang;

  @override
  void initState() {
    super.initState();
    _autoTranslate = widget.initialTranslate;
    _targetLang = widget.initialLang;
  }

  void _setTranslate(bool v) {
    setState(() => _autoTranslate = v);
    widget.onTranslateChanged?.call(v);
    _showToast(v ? 'Translate: ON' : 'Translate: OFF');
  }

  void _setLang(String v) {
    setState(() => _targetLang = v);
    widget.onLangChanged?.call(v);
    _showToast('Language: ${_langName(v)}');
  }

  void _showToast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  // ---- UI helpers ----
  String _langName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ar':
        return 'Arabic';
      case 'hi':
        return 'Hindi';
      case 'ja':
        return 'Japanese';
      case 'es':
        return 'Spanish';
      default:
        return code.toUpperCase();
    }
  }

  String _flag(String code) {
    switch (code) {
      case 'en':
        return '🇬🇧';
      case 'ar':
        return '🇦🇪';
      case 'hi':
        return '🇮🇳';
      case 'ja':
        return '🇯🇵';
      case 'es':
        return '🇪🇸';
      default:
        return '🌐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Links')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _TranslateTileRow(
            spinning: _autoTranslate,
            langCode: _targetLang,
            langLabel: '${_flag(_targetLang)}  ${_langName(_targetLang)}',
            onToggle: _setTranslate,
            onLangChanged: _setLang,
          ),
          const SizedBox(height: 12),
          _ActionRow(
            icon: const Icon(Icons.shield_outlined),
            title: 'Privacy',
            subtitle: 'You control what’s shared.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyControlScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionRow(
            icon: const Icon(Icons.description_outlined),
            title: 'Documents',
            subtitle: 'One place to store your files safely.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (widget.currentUser == null) {
                _showToast('Please sign in to view Documents');
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      DocumentsScreen(currentUser: widget.currentUser!),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionRow(
            icon: const Icon(Icons.add),
            title: 'More',
            subtitle: 'Pin more shortcuts.',
            trailing: const Icon(Icons.chevron_right),
            onTap: _showMoreSheet,
          ),
        ],
      ),
    );
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool stories = true;
        bool aiHub = true;
        bool settings = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Pin shortcuts',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: stories,
                  onChanged: (v) => setSheet(() => stories = v ?? false),
                  title: const Text('My Stories'),
                ),
                CheckboxListTile(
                  value: aiHub,
                  onChanged: (v) => setSheet(() => aiHub = v ?? false),
                  title: const Text('AI Hub'),
                ),
                CheckboxListTile(
                  value: settings,
                  onChanged: (v) => setSheet(() => settings = v ?? false),
                  title: const Text('Settings'),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showToast('Shortcuts updated');
                  },
                  child: const Text('Done'),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ---------- Rows (full-width tiles) ---------- */

class _ActionRow extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white.withOpacity(0.06) : Colors.white;
    final border = BorderSide(
      color: isDark
          ? Colors.white.withOpacity(.08)
          : Colors.black.withOpacity(.06),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.fromBorderSide(border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _TranslateTileRow extends StatelessWidget {
  final bool spinning;
  final String langCode;
  final String langLabel;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onLangChanged;

  const _TranslateTileRow({
    required this.spinning,
    required this.langCode,
    required this.langLabel,
    required this.onToggle,
    required this.onLangChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white.withOpacity(0.06) : Colors.white;
    final border = BorderSide(
      color: isDark
          ? Colors.white.withOpacity(.08)
          : Colors.black.withOpacity(.06),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {}, // controls inside
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.fromBorderSide(border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header row with spinning globe + switch
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(.10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _QuickSpinningGlobe(spinning: spinning),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Translate',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.92,
                    child: Switch.adaptive(
                      value: spinning,
                      onChanged: onToggle,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Microcopy
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Translate your chats in real time.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              // Language dropdown (flag + name)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: langCode,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onChanged: (v) {
                        if (v != null) onLangChanged(v);
                      },
                      items:
                          const [
                            MapEntry('en', '🇬🇧  English'),
                            MapEntry('ar', '🇦🇪  Arabic'),
                            MapEntry('hi', '🇮🇳  Hindi'),
                            MapEntry('ja', '🇯🇵  Japanese'),
                            MapEntry('es', '🇪🇸  Spanish'),
                          ].map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
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

class _QuickSpinningGlobe extends StatefulWidget {
  final bool spinning;
  const _QuickSpinningGlobe({required this.spinning});

  @override
  State<_QuickSpinningGlobe> createState() => _QuickSpinningGlobeState();
}

class _QuickSpinningGlobeState extends State<_QuickSpinningGlobe>
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
  void didUpdateWidget(covariant _QuickSpinningGlobe oldWidget) {
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
      child: const Icon(Icons.public, size: 22, color: Colors.blue),
    );
  }
}
