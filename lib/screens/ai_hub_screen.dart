import 'package:flutter/material.dart';
import 'personal_bot_builder_screen.dart';

class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blue = Colors.blue;

    Chip _tag(String label) => Chip(
      label: Text(label),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: blue.withOpacity(0.75),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );

    Card botCard({
      required IconData icon,
      required String name,
      required String blurb,
      required String price,
      List<String> tags = const [],
      VoidCallback? onTap,
    }) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: blue.withOpacity(0.25), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: blue.withOpacity(0.12),
              child: Icon(icon, color: blue),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(blurb),
                if (tags.isNotEmpty) const SizedBox(height: 6),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: tags.map(_tag).toList(),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '\$$price',
                  style: TextStyle(color: blue, fontWeight: FontWeight.w800),
                ),
                const Text('/mo', style: TextStyle(fontSize: 11)),
              ],
            ),
            onTap:
                onTap ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name is coming soon'),
                      duration: const Duration(milliseconds: 1800),
                    ),
                  );
                },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Hub'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.smart_toy_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PersonalBotBuilderScreen()),
          );
        },
        backgroundColor: blue,
        icon: const Icon(Icons.add),
        label: const Text('Create bot'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [blue.withOpacity(0.18), blue.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: blue.withOpacity(0.25), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: blue.withOpacity(0.15),
                  child: Icon(Icons.smart_toy_outlined, color: blue, size: 30),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Build your own custom AI chatbot.\nPick a template or start from scratch.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PersonalBotBuilderScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.add_circle_outline, color: blue),
                  label: Text(
                    'Create',
                    style: TextStyle(color: blue, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Featured: My Life Story (personal twin)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: blue.withOpacity(0.35), width: 1),
            ),
            color: blue.withOpacity(0.06),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: blue.withOpacity(0.16),
                child: Icon(Icons.account_circle_outlined, color: blue),
              ),
              title: const Text(
                'My Life Story (Personal Twin)',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Feed it your background & memories. Chat with a bot that truly knows you.',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PersonalBotBuilderScreen(),
                  ),
                );
              },
            ),
          ),

          // Categories
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Text(
              'Popular categories',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag('Health'),
              _tag('Coaching'),
              _tag('Travel'),
              _tag('Learning'),
              _tag('Cooking'),
              _tag('Productivity'),
            ],
          ),

          // Templates
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Text(
              'Templates',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          botCard(
            icon: Icons.local_hospital_outlined,
            name: 'Dr. Clear',
            blurb: 'Health info & symptom guidance',
            price: '9.99',
            tags: const ['Health', 'Wellbeing'],
          ),
          botCard(
            icon: Icons.self_improvement,
            name: 'Life Coach',
            blurb: 'Goals, habits, and motivation',
            price: '7.99',
            tags: const ['Coaching', 'Productivity'],
          ),
          botCard(
            icon: Icons.flight_takeoff,
            name: 'Travel Genie',
            blurb: 'Trips, itineraries, and hidden gems',
            price: '6.99',
            tags: const ['Travel'],
          ),
          botCard(
            icon: Icons.school_outlined,
            name: 'Study Buddy',
            blurb: 'Homework help & exam prep',
            price: '4.99',
            tags: const ['Learning'],
          ),
          botCard(
            icon: Icons.restaurant_menu,
            name: 'Chef Pro',
            blurb: 'Recipes & meal plans',
            price: '3.99',
            tags: const ['Cooking'],
          ),
        ],
      ),
    );
  }
}
