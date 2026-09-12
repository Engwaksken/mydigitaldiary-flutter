import 'package:flutter/material.dart';
import '../services/privacy_service.dart';
import '../services/api_client.dart';
import 'personalisation_screen.dart';

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  final _service = PrivacyService();
  final _reason = TextEditingController();
  final _password = TextEditingController();
  final Set<String> _modules = {
    'daily_plans',
    'expenses',
    'savings_goals',
    'notes'
  };
  Map<String, dynamic>? _status;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _emailBackup = true;
  bool _busy = false;

  static const labels = {
    'plans': 'Annual Plans',
    'daily_plans': 'Daily Planner',
    'incomes': 'Income',
    'budgets': 'Budgets',
    'expenses': 'Expenses',
    'debts': 'Debts',
    'savings_goals': 'Savings Goals',
    'savings_contributions': 'Savings Contributions',
    'diet_logs': 'Diet',
    'exercise_logs': 'Exercise',
    'sleep_logs': 'Sleep',
    'health_checkups': 'Health',
    'projects': 'Projects',
    'project_tasks': 'Tasks',
    'reminders': 'Reminders',
    'spiritual_practices': 'Spiritual Growth',
    'notes': 'Notes',
    'ai_plans': 'AI Planner',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await _service.status();
      if (mounted) setState(() => _status = value);
    } catch (_) {}
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final initial =
        from ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now());
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (result == null) return;
    setState(() {
      if (from) {
        _dateFrom = result;
        if (_dateTo != null && _dateTo!.isBefore(result)) _dateTo = result;
      } else {
        _dateTo = result;
        if (_dateFrom != null && _dateFrom!.isAfter(result)) _dateFrom = result;
      }
    });
  }

  String _dateLabel(DateTime? date, String empty) => date == null
      ? empty
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _requestReport() async {
    if (_reason.text.trim().isEmpty || _modules.isEmpty) {
      _message('Enter a reason and select at least one section.');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await _service.requestReport(
        reason: _reason.text.trim(),
        modules: _modules.toList(),
        from: _dateFrom,
        to: _dateTo,
      );
      _message(
          response['message']?.toString() ?? 'Report generated and emailed.');
      await _load();
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scheduleDeletion() async {
    if (_reason.text.trim().isEmpty || _password.text.isEmpty) {
      _message('Enter your reason and current password.');
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Schedule account deletion?'),
            content: const Text(
              'Your account will be scheduled for permanent deletion after 30 days. '
              'You can cancel during the grace period. After permanent deletion, your data cannot be restored.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm deletion')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      final response = await _service.scheduleDeletion(
        password: _password.text,
        reason: _reason.text.trim(),
        backup: _emailBackup,
      );
      _message(
          response['message']?.toString() ?? 'Account deletion scheduled.');
      await _load();
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deletion = _status?['scheduled_deletion_at'];
    final reports = (_status?['reports'] as List? ?? const []);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.shield_outlined,
                            color: Color(0xFF047857)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('Privacy & Trust',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _PrivacyPoint(
                    icon: Icons.lock_outline,
                    title: 'Private by default',
                    text:
                        'Your diary entries are not published or shared with other users by default. My Digital Diary does not sell private diary data for third-party advertising.',
                  ),
                  const _PrivacyPoint(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Who can technically access stored data?',
                    text:
                        'Authorised system administrators may access stored information only when needed for support, security, maintenance, fraud prevention or legal obligations. Access should be limited to people who genuinely need it.',
                  ),
                  const _PrivacyPoint(
                    icon: Icons.auto_awesome_outlined,
                    title: 'You control AI access',
                    text:
                        'Choose which life areas AI features may use. You can exclude Finance, Health, Notes, Spiritual Growth or other areas whenever you prefer.',
                  ),
                  const _PrivacyPoint(
                    icon: Icons.cloud_outlined,
                    title: 'Cloud diary, honest limits',
                    text:
                        'A cloud diary must store data on servers to sync devices and provide reminders, reports and backups. No online service can promise that authorised operators can never access stored data, so transparency and access controls matter.',
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PersonalisationScreen())),
                      icon: const Icon(Icons.tune_outlined),
                      label: const Text('Review AI privacy choices'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personal Data Report',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Why do you need the report?'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Period range'),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(from: true),
                          icon: const Icon(Icons.date_range_outlined),
                          label: Text(_dateLabel(_dateFrom, 'From date')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(from: false),
                          icon: const Icon(Icons.event_outlined),
                          label: Text(_dateLabel(_dateTo, 'To date')),
                        ),
                      ),
                    ],
                  ),
                  if (_dateFrom != null || _dateTo != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _dateFrom = null;
                          _dateTo = null;
                        }),
                        child: const Text('Clear dates'),
                      ),
                    ),
                  const Text('Information to include'),
                  ...labels.entries.map(
                    (entry) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      value: _modules.contains(entry.key),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _modules.add(entry.key);
                        } else {
                          _modules.remove(entry.key);
                        }
                      }),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _requestReport,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Generate & email PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (reports.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent reports',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...reports.take(5).map((row) {
                      final report = Map<String, dynamic>.from(row as Map);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(report['status']?.toString() ?? 'Unknown'),
                        subtitle: Text(report['created_at']?.toString() ?? ''),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            color: deletion != null ? Colors.amber.shade50 : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Delete My Account',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 8),
                  if (deletion != null) ...[
                    Text('Scheduled for permanent deletion: $deletion'),
                    const SizedBox(height: 4),
                    const Text(
                        'Data cannot be restored after permanent deletion.'),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await _service.cancelDeletion();
                              _message('Account deletion cancelled.');
                              await _load();
                            },
                      child: const Text('Cancel Account Deletion'),
                    ),
                  ] else ...[
                    const Text(
                        'Tell us why you want to delete your account, then confirm with your password.'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Current password'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                          'Email me a complete data backup before deletion'),
                      value: _emailBackup,
                      onChanged: (value) =>
                          setState(() => _emailBackup = value ?? true),
                    ),
                    FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _busy ? null : _scheduleDeletion,
                      child:
                          const Text('Schedule deletion (30-day grace period)'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _PrivacyPoint(
      {required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 3),
                Text(text,
                    style: const TextStyle(
                        fontSize: 12, height: 1.4, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
