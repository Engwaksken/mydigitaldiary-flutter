import 'package:flutter/material.dart';
import '../config/module_configs.dart';
import 'dynamic_crud_screen.dart';

/// Static FAQ, mirroring resources/views/help/show.blade.php's content
/// exactly - kept in sync manually since it's small and rarely changes,
/// rather than adding a whole API round-trip for a handful of static
/// paragraphs.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _sections = {
    'Getting Started': {
      'How do I get started?':
          'After creating your account and verifying your email, you land on your dashboard. Use the drawer menu to reach any module - Expenses, Income, Meetings, and so on.',
      'Is my data private?':
          'Yes - everything you track is scoped to your own account. Nobody else, including other users on a Family/Team or Enterprise plan, can see your personal tracking data.',
    },
    'Tracking & Modules': {
      'How do reminders work?':
          "Set a reminder with a schedule (once, daily, weekly, etc.) and choose how you're notified - email, in-app, or both. Reminders always show up in your Notifications list regardless of which delivery method you choose.",
      'What is the AI Planner?':
          'It generates a personalized plan based on your existing tracked data. You can generate a new one anytime, download any past plan as a PDF, or delete ones you no longer need.',
      'How do I sign a document?':
          'On mobile, you can view and download signed documents and saved signatures - the full drag-and-drop signing editor is web-only.',
    },
    'Subscription & Billing': {
      'What plans are available?':
          'Individual plans for one person, Family & Small Team for a handful of people, and Enterprise for larger organizations - Enterprise pricing is handled through a quick "Contact Sales" form rather than self-serve checkout.',
      'How do I manage my team?':
          "If you're on a Family & Team or Enterprise plan, use the Organization page to invite, activate, deactivate, or remove members.",
      'What happens if someone leaves my organization?':
          'Their seat is freed immediately, and their access to organization-owned resources is revoked. Their own personal tracking data stays with them.',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._sections.entries.map((section) => Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(section.key,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      ...section.value.entries.map((qa) => ExpansionTile(
                            title: Text(qa.key,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(qa.value,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black54)),
                              ),
                            ],
                          )),
                    ],
                  ),
                ),
              )),
          Card(
            color: const Color(0xFFF8FAFC),
            child: ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text("Didn't find what you're looking for?"),
              subtitle: const Text('Send us feedback'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => DynamicCrudScreen(
                        config: moduleConfigByEndpoint('feedback'))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
