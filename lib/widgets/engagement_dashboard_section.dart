import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class EngagementDashboardSection extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool loading;
  final VoidCallback onStartDay;
  final VoidCallback onCloseDay;
  final VoidCallback onWeekReview;
  final VoidCallback onMonthReview;

  const EngagementDashboardSection({
    super.key,
    required this.data,
    required this.loading,
    required this.onStartDay,
    required this.onCloseDay,
    required this.onWeekReview,
    required this.onMonthReview,
  });

  Map<String, dynamic> _map(String key) {
    final raw = data[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final streak = _map('streak');
    final start = _map('start_day');
    final close = _map('close_day');
    final progress = _map('progress');

    final current = streak['current'] ?? 0;
    final best = streak['best'] ?? 0;
    final startDone = start['completed'] == true;
    final closeDone = close['completed'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.amber,
                size: 36,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$current-Day Growth Streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Best: $best days · meaningful actions count',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: startDone
                    ? Icons.check_circle_outline_rounded
                    : Icons.wb_sunny_outlined,
                title: startDone ? 'Day started' : 'Start My Day',
                subtitle: startDone
                    ? 'Your priorities are set.'
                    : 'Choose what matters most.',
                onTap: startDone ? null : onStartDay,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ActionCard(
                icon: closeDone
                    ? Icons.check_circle_outline_rounded
                    : Icons.nights_stay_outlined,
                title: closeDone ? 'Day closed' : 'Close My Day',
                subtitle: closeDone
                    ? 'Today is reflected.'
                    : 'Finish today with clarity.',
                onTap: closeDone ? null : onCloseDay,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights_outlined, color: Color(0xFF7C3AED)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${progress['tasks_completed'] ?? 0}/${progress['tasks_total'] ?? 0} tasks · '
                  '${progress['meaningful_actions'] ?? 0} meaningful action(s)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onWeekReview,
                icon: const Icon(Icons.date_range_outlined, size: 17),
                label: const Text('Week'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onMonthReview,
                icon: const Icon(Icons.calendar_month_outlined, size: 17),
                label: const Text('Month'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EngagementReviewSheet extends StatelessWidget {
  final String period;
  final Map<String, dynamic> review;

  const EngagementReviewSheet({
    super.key,
    required this.period,
    required this.review,
  });

  String _money(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return 'UGX ${n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final streak = review['streak'] is Map
        ? Map<String, dynamic>.from(review['streak'] as Map)
        : <String, dynamic>{};

    final title = period == 'week' ? 'My Week in Review' : 'My Month in Review';

    final metrics = <(String, String)>[
      (
        'Tasks',
        '${review['tasks_completed'] ?? 0}/${review['tasks_total'] ?? 0}',
      ),
      ('Completion', '${review['completion_percent'] ?? 0}%'),
      ('Meaningful days', '${review['meaningful_days'] ?? 0}'),
      ('Exercise', '${review['exercise_sessions'] ?? 0} sessions'),
      ('Income', _money(review['income'])),
      ('Expenses', _money(review['expenses'])),
      ('Current streak', '${streak['current'] ?? 0} days'),
      ('Best streak', '${streak['best'] ?? 0} days'),
    ];

    final shareText = [
      title,
      '',
      ...metrics.take(4).map((m) => '${m.$1}: ${m.$2}'),
      '',
      'My Digital Diary',
    ].join('\n');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Progress worth noticing and sharing.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            if ((review['period_start'] ?? '').toString().isNotEmpty &&
                (review['period_end'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${review['period_start']} – ${review['period_end']}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
            const SizedBox(height: 16),
            GridView.builder(
              itemCount: metrics.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                mainAxisExtent: 88,
              ),
              itemBuilder: (_, index) {
                final metric = metrics[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.$1,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        metric.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                    subject: title,
                  ),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share My Progress'),
            ),
          ],
        ),
      ),
    );
  }
}
