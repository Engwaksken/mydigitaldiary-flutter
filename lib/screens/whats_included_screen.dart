import 'package:flutter/material.dart';

class WhatsIncludedScreen extends StatelessWidget {
  const WhatsIncludedScreen({super.key});

  static const _sections = [
    (
      'Planning & Productivity',
      Icons.event_note_outlined,
      Color(0xFF4F46E5),
      [
        'Annual & Monthly Plans - set yearly goals, break them into months, track progress, target dates and reminders',
        'Daily Planner & Top 3 - plan each day, prioritize important items, use timed tasks and review planner history',
        'Daily 8:00 AM Top 3 Digest - receive your most important items for the day as a reminder',
        'Smart Reminders - one-time or recurring reminders with in-app, email and push delivery',
        'AI Planner - generate personalized planning suggestions from your tracked information',
      ],
    ),
    (
      'Money & Financial Planning',
      Icons.account_balance_wallet_outlined,
      Color(0xFF059669),
      [
        'Income - record and review money received',
        'Budgets - create category spending limits and track performance',
        'Expenses - log purchases manually or scan a receipt/document to extract expense details automatically',
        'Itemized Receipts - keep the individual purchased items, quantities and prices with an expense',
        'Debts - monitor amounts you owe or amounts owed to you',
        'Savings Goals & Contributions - track progress toward specific savings targets',
        'Financial Planner - model retirement savings, contributions, expected returns, inflation and future income goals',
      ],
    ),
    (
      'Work, Projects & Meetings',
      Icons.work_outline,
      Color(0xFF2563EB),
      [
        'Projects - organize work by status and deadline',
        'Project Tasks - choose a project and manage actionable tasks without entering project IDs',
        'Meetings - schedule and manage meeting details',
        'Meeting Recording - record or upload meeting audio',
        'Transcripts & AI Summaries - process recordings into meeting notes and summaries',
        'Shareable Meeting Notes - email or share meeting outputs when needed',
      ],
    ),
    (
      'Health & Wellness',
      Icons.favorite_border,
      Color(0xFFE11D48),
      [
        'Diet Logs - track meals, foods and nutrition information',
        'Exercise Logs - record workouts, duration and intensity',
        'Sleep Logs - monitor sleep duration and quality',
        'Health Checkups - keep upcoming and completed health appointments',
      ],
    ),
    (
      'Personal Growth',
      Icons.auto_awesome_outlined,
      Color(0xFF8B5CF6),
      [
        'Education Plans - manage learning goals, courses and completion targets',
        'Network Contacts - track professional contacts and follow-ups',
        'Personal Relationships - plan check-ins with people who matter',
        'Spiritual Growth - track prayer, devotion, fasting, meditation and other practices',
      ],
    ),
    (
      'Documents & Identity',
      Icons.description_outlined,
      Color(0xFF0F766E),
      [
        'Document Scanner - scan paper receipts/documents with automatic edge detection and cleanup',
        'Digital Signatures - save signatures and apply them to documents',
        'Signed Documents - keep and manage signed-document history',
        'Digital Business Card - create a branded shareable card with profile image, link and QR code',
        'Profile & Avatar - manage your profile information and photo across the app',
      ],
    ),
    (
      'Reports, Billing & Account',
      Icons.dashboard_customize_outlined,
      Color(0xFFD97706),
      [
        'Personal Report PDF - download a cross-module summary of your tracked information',
        'Subscription - view your current plan and account payment phone',
        'Invoices & Receipts - review and download billing documents',
        'Mobile Money - start or complete pending MTN/Airtel payment prompts',
        'Bank Transfer - submit a reference for supported bank/manual payments',
        'Push Notifications - receive supported reminders even when the app is in the background',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("What's Included")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Explore My Digital Diary',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'A single workspace for planning, finances, wellness, projects, meetings, reminders, documents and personal reporting.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 18),
          ..._sections.map((section) {
            final (title, icon, color, features) = section;
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...features.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Icon(Icons.check_circle_outline,
                                  size: 18, color: color),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
