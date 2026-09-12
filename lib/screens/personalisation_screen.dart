import 'package:flutter/material.dart';
import '../services/api_client.dart';

class PersonalisationScreen extends StatefulWidget {
  const PersonalisationScreen({super.key});

  @override
  State<PersonalisationScreen> createState() => _PersonalisationScreenState();
}

class _PersonalisationScreenState extends State<PersonalisationScreen> {
  bool _loading = true;
  bool _saving = false;
  final Set<String> _ai = {};
  final Set<String> _focuses = {};
  final Map<String, bool> _notifyPrefs = {
    'goal_progress': true,
    'monthly_review': true,
    'finance_insights': true,
    'productivity_nudges': true,
    'spiritual_insights': true,
    'subscription_reminders': true,
    'daily_affirmations': true,
  };

  static const _aiOptions = <String, String>{
    'planning': 'Planning & tasks', 'finance': 'Finance', 'goals': 'Goals', 'health': 'Health',
    'wellbeing': 'Exercise, diet & sleep', 'spiritual': 'Spiritual Growth', 'notes': 'Personal Notes',
    'meetings': 'Meetings', 'network': 'Network Contacts', 'education': 'Education', 'relationships': 'Relationships',
  };
  static const _notifyOptions = <String, List<String>>{
    'goal_progress': ['Goal progress alerts', 'Only when an important goal needs attention'],
    'monthly_review': ['Monthly review ready', 'Know when your new monthly review is available'],
    'finance_insights': ['Finance insights', 'Helpful spending, saving and financial-health nudges'],
    'productivity_nudges': ['Productivity nudges', 'Occasional next-best-action reminders'],
    'spiritual_insights': ['Spiritual Growth insights', 'Allow spiritual reflection prompts in insights'],
    'daily_affirmations': ['Daily affirmations', 'Show a fresh motivational affirmation in Today’s Insight rotation'],
    'subscription_reminders': ['Subscription reminders', 'Important trial and subscription expiry reminders'],
  };
  static const _focusOptions = <String, String>{
    'money': 'Manage my money', 'day': 'Organise my day', 'goals': 'Reach my goals', 'health': 'Improve my health',
    'work': 'Manage work/business', 'growth': 'Personal growth', 'everything': 'Everything',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.instance.get('personalisation');
      if (!mounted) return;
      setState(() {
        _ai
          ..clear()
          ..addAll((data['ai_data_permissions'] as List? ?? const []).map((e) => e.toString()));
        _focuses
          ..clear()
          ..addAll((data['onboarding_focuses'] as List? ?? const []).map((e) => e.toString()));
        final prefs = data['engagement_notification_preferences'];
        if (prefs is Map) {
          for (final entry in _notifyPrefs.keys.toList()) {
            if (prefs.containsKey(entry)) _notifyPrefs[entry] = prefs[entry] == true || prefs[entry] == 1;
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.put('personalisation', {
        'ai_data_permissions': _ai.toList(),
        'onboarding_focuses': _focuses.toList(),
        'complete_onboarding': true,
        'engagement_notification_preferences': _notifyPrefs,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personalisation saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalisation & AI Privacy')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('What should My Digital Diary help you with most?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Choose the areas you care about most. This helps us prioritise guidance and shortcuts.', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _focusOptions.entries.map((entry) => FilterChip(
                    label: Text(entry.value),
                    selected: _focuses.contains(entry.key),
                    onSelected: (selected) => setState(() => selected ? _focuses.add(entry.key) : _focuses.remove(entry.key)),
                  )).toList(),
                ),
                const SizedBox(height: 26),
                Text('What may AI Planner use?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('You stay in control. Turn off any part of your diary you do not want included in AI context.', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                ..._aiOptions.entries.map((entry) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _ai.contains(entry.key),
                  title: Text(entry.value),
                  onChanged: (value) => setState(() => value == true ? _ai.add(entry.key) : _ai.remove(entry.key)),
                )),
                const SizedBox(height: 26),
                Text('Smart notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Choose the helpful nudges you want. Essential security and account messages remain enabled.', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                ..._notifyOptions.entries.map((entry) => SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _notifyPrefs[entry.key] ?? true,
                  title: Text(entry.value.first, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(entry.value.last),
                  onChanged: (value) => setState(() => _notifyPrefs[entry.key] = value),
                )),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('Save choices')),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
