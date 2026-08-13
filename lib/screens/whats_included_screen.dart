import 'package:flutter/material.dart';

/// A feature-tour screen for the Home tab's "Explore What's Included"
/// link — mirrors the same module groupings shown in the drawer (see
/// widgets/app_drawer.dart) and the feature list on the web app's own
/// guest/login page, just presented as a browsable tour rather than a
/// functional navigation list.
class WhatsIncludedScreen extends StatelessWidget {
  const WhatsIncludedScreen({super.key});

  static const _sections = [
    (
      'Finance',
      Icons.savings_outlined,
      Color(0xFF059669),
      [
        'Annual Plans — set yearly goals and track completion progress',
        'Income — track every source of money coming in',
        'Budgets — set spending limits by category',
        'Expenses — log spending with running totals',
        'Debts — track what you owe and to whom',
        'Savings Goals & Contributions — save toward something specific',
      ],
    ),
    (
      'Health & Wellness',
      Icons.favorite_border,
      Color(0xFFE11D48),
      [
        'Diet Logs — what you ate and when',
        'Exercise Logs — workouts and activity',
        'Sleep Logs — track sleep duration and quality',
        'Health Checkups — upcoming and past appointments',
      ],
    ),
    (
      'Work & Projects',
      Icons.work_outline,
      Color(0xFF3B82F6),
      [
        'Projects — track work with statuses and deadlines',
        'Project Tasks — break projects into actionable steps',
        'Meetings — schedule, record, and get AI summaries',
      ],
    ),
    (
      'Personal Life',
      Icons.groups_2_outlined,
      Color(0xFF8B5CF6),
      [
        'Education Plans — courses and learning goals',
        'Network Contacts — professional relationships',
        'Personal Relationships — stay in touch with people who matter',
        'Spiritual Practices — track personal practices and habits',
      ],
    ),
    (
      'Productivity & AI',
      Icons.bolt_outlined,
      Color(0xFFD97706),
      [
        'Reminders — with in-app alarms, not just notifications',
        'AI Planner — a personalized plan generated from your own data',
        'Global Search — find anything across your tracked data',
      ],
    ),
    (
      'Tools & Account',
      Icons.build_outlined,
      Color(0xFF00897B),
      [
        'Signatures — save and use signatures to sign documents',
        'Business Card — a shareable digital card with your own colors',
        'Family, Team & Organization — invite others to a shared plan',
        'Appearance — your own colors and font, just for you',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("What's Included")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Everything below is included in your plan — one app for the parts of life '
            "you're already keeping track of.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ..._sections.map((section) {
            final (title, icon, color, items) = section;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: color.withValues(alpha: 0.6)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
