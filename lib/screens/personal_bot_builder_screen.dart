import 'package:flutter/material.dart';

class PersonalBotBuilderScreen extends StatefulWidget {
  const PersonalBotBuilderScreen({super.key});

  @override
  State<PersonalBotBuilderScreen> createState() =>
      _PersonalBotBuilderScreenState();
}

class _PersonalBotBuilderScreenState extends State<PersonalBotBuilderScreen> {
  final _nameCtrl = TextEditingController(text: 'My Life Story Bot');
  final _storyCtrl = TextEditingController();
  String _tone = 'Warm';
  bool _privateOnly = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _storyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    // TODO: persist to Firestore or your backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved! (builder functionality coming soon)'),
        duration: Duration(milliseconds: 1800),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blue = Colors.blue;

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Bot Builder')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [blue.withOpacity(0.18), blue.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: blue.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: blue.withOpacity(0.15),
                  child: Icon(Icons.smart_toy_outlined, color: blue, size: 30),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Feed it your background, milestones, preferences, and memories.\nChat with a bot that truly knows you.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Name
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Bot name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Tone
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tone',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _tone,
                items: const [
                  DropdownMenuItem(value: 'Warm', child: Text('Warm')),
                  DropdownMenuItem(
                    value: 'Professional',
                    child: Text('Professional'),
                  ),
                  DropdownMenuItem(value: 'Playful', child: Text('Playful')),
                  DropdownMenuItem(value: 'Direct', child: Text('Direct')),
                ],
                onChanged: (v) => setState(() => _tone = v ?? _tone),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Life story
          TextField(
            controller: _storyCtrl,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Your life story / background',
              hintText:
                  'Write freely, or paste from notes. You can add achievements, preferences, people, places, timelines…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),

          // Privacy
          SwitchListTile(
            title: const Text('Keep this private (visible only to you)'),
            subtitle: const Text(
              'We’ll store it securely and use it only for this bot.',
            ),
            value: _privateOnly,
            onChanged: (v) => setState(() => _privateOnly = v),
          ),

          const SizedBox(height: 8),
          // Import row (placeholders)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Import from file coming soon'),
                      duration: Duration(milliseconds: 1800),
                    ),
                  );
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Import file'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link Google Docs coming soon'),
                      duration: Duration(milliseconds: 1800),
                    ),
                  );
                },
                icon: const Icon(Icons.description_outlined),
                label: const Text('Link Google Docs'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save & Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: you can edit or expand this later as your story grows.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
