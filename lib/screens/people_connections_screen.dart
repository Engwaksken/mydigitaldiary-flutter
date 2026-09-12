import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/personal_management_service.dart';
import '../services/ai_form_assist_service.dart';

enum PeopleConnectionsMode { relationships, networks }

class PeopleConnectionsScreen extends StatefulWidget {
  final PeopleConnectionsMode mode;
  const PeopleConnectionsScreen.relationships({super.key}) : mode = PeopleConnectionsMode.relationships;
  const PeopleConnectionsScreen.networks({super.key}) : mode = PeopleConnectionsMode.networks;

  @override
  State<PeopleConnectionsScreen> createState() => _PeopleConnectionsScreenState();
}

class _PeopleConnectionsScreenState extends State<PeopleConnectionsScreen> {
  final _service = const PersonalManagementService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  bool get _relationships => widget.mode == PeopleConnectionsMode.relationships;
  String get _endpoint => _relationships ? 'relationships' : 'network-contacts';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rows = await _service.list(_endpoint);
      if (!mounted) return;
      setState(() { _items = rows; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load connections.'; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      final haystack = [
        item['name'], item['category'], item['relationship_type'], item['network_groups'],
        item['company'], item['met_through'], item['notes']
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  int? _daysSince(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return null;
    return DateTime.now().difference(date).inDays;
  }

  Future<void> _form([Map<String, dynamic>? existing]) async {
    if (_relationships) {
      await _relationshipForm(existing);
    } else {
      await _networkForm(existing);
    }
  }

  Future<void> _relationshipForm(Map<String, dynamic>? existing) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    bool aiLoading = false;
    final relation = TextEditingController(text: existing?['relation_label']?.toString() ?? '');
    final email = TextEditingController(text: existing?['email']?.toString() ?? '');
    final phone = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final interaction = TextEditingController(text: existing?['interaction_notes']?.toString() ?? '');
    final interests = TextEditingController(text: existing?['interests']?.toString() ?? '');
    final commitments = TextEditingController(text: existing?['commitments']?.toString() ?? '');
    final followups = TextEditingController(text: existing?['follow_up_items']?.toString() ?? '');
    final strengthening = TextEditingController(text: existing?['strengthening_goal']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    String category = existing?['category']?.toString() ?? '';
    String priority = existing?['priority']?.toString() ?? 'medium';
    DateTime? last = DateTime.tryParse(existing?['last_meaningful_interaction']?.toString() ?? '');
    DateTime? next = DateTime.tryParse(existing?['next_planned_interaction']?.toString() ?? '');
    DateTime? birthday = DateTime.tryParse(existing?['birthday']?.toString() ?? '');
    DateTime? anniversary = DateTime.tryParse(existing?['anniversary']?.toString() ?? '');

    try {
      final save = await _scrollSheet(
        existing == null ? 'Add Important Person' : 'Edit Relationship',
        (context, setLocal) => [
          TextField(
            controller: name,
            onChanged: (_) => setLocal(() {}),
            decoration: const InputDecoration(labelText: 'Name *'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: category.isEmpty ? null : category,
            decoration: const InputDecoration(
              labelText: 'Category / relationship type *',
            ),
            hint: const Text('Select relationship type'),
            items: const [
              DropdownMenuItem(value:'family',child:Text('Family')),
              DropdownMenuItem(value:'friend',child:Text('Friend')),
              DropdownMenuItem(value:'colleague',child:Text('Colleague')),
              DropdownMenuItem(value:'mentor',child:Text('Mentor')),
              DropdownMenuItem(value:'partner',child:Text('Partner')),
              DropdownMenuItem(value:'client',child:Text('Client')),
              DropdownMenuItem(value:'professional',child:Text('Professional')),
              DropdownMenuItem(value:'other',child:Text('Other')),
            ],
            onChanged: (v) => setLocal(() => category = v ?? ''),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: relation,
            onChanged: (_) => setLocal(() {}),
            decoration: const InputDecoration(
              labelText: 'Relationship / connection topic',
              hintText: 'e.g. sister, manager, accountability partner',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC4B5FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'AI Generate',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add the person, relationship type or connection topic above. AI fills only empty planning fields, and you can edit everything before saving.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: aiLoading ||
                          (name.text.trim().isEmpty &&
                              relation.text.trim().isEmpty &&
                              category.isEmpty)
                      ? null
                      : () async {
                          final topic = relation.text.trim().isNotEmpty
                              ? relation.text.trim()
                              : name.text.trim().isNotEmpty
                                  ? name.text.trim()
                                  : category;

                          setLocal(() => aiLoading = true);
                          try {
                            final draft = await const AiFormAssistService().generate(
                              module: 'relationships',
                              topic: topic,
                              context: <String, dynamic>{
                                if (name.text.trim().isNotEmpty)
                                  'name': name.text.trim(),
                                if (category.isNotEmpty)
                                  'category': category,
                                if (relation.text.trim().isNotEmpty)
                                  'relation_label': relation.text.trim(),
                                'priority': priority,
                                if (interests.text.trim().isNotEmpty)
                                  'interests': interests.text.trim(),
                              },
                            );

                            void fill(
                              TextEditingController controller,
                              String key,
                            ) {
                              if (controller.text.trim().isEmpty &&
                                  draft[key] != null) {
                                controller.text = draft[key].toString();
                              }
                            }

                            fill(interaction, 'interaction_notes');
                            fill(interests, 'interests');
                            fill(commitments, 'commitments');
                            fill(followups, 'follow_up_items');
                            fill(strengthening, 'strengthening_goal');
                            fill(notes, 'notes');
                            setLocal(() {});
                          } on ApiException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                          } finally {
                            setLocal(() => aiLoading = false);
                          }
                        },
                  icon: aiLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(aiLoading ? 'Generating...' : 'AI Generate'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: const [
              DropdownMenuItem(value:'high',child:Text('High')), DropdownMenuItem(value:'medium',child:Text('Medium')), DropdownMenuItem(value:'low',child:Text('Low')),
            ],
            onChanged: (v) => setLocal(() => priority = v ?? 'medium'),
          ),
          const SizedBox(height: 10),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          _dateTile(context, setLocal, 'Birthday', birthday, (v) => birthday = v),
          _dateTile(context, setLocal, 'Anniversary', anniversary, (v) => anniversary = v),
          _dateTile(context, setLocal, 'Last meaningful interaction', last, (v) => last = v),
          _dateTile(context, setLocal, 'Next call / meeting / check-in', next, (v) => next = v),
          TextField(controller: interaction, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Previous interaction / conversation notes')),
          const SizedBox(height: 10),
          TextField(controller: interests, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Interests / things they care about')),
          const SizedBox(height: 10),
          TextField(controller: commitments, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Commitments / promises')),
          const SizedBox(height: 10),
          TextField(controller: followups, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Follow-up items')),
          const SizedBox(height: 10),
          TextField(controller: strengthening, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'How I will strengthen this relationship')),
          const SizedBox(height: 10),
          TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Personal notes')),
        ],
      );
      if (save != true) return;

      if (name.text.trim().isEmpty || category.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add the person and select a relationship type.'),
            ),
          );
        }
        return;
      }

      final body = {
        'name': name.text.trim(), 'category': category, 'relation_label': relation.text.trim().isEmpty ? null : relation.text.trim(),
        'priority': priority, 'email': email.text.trim().isEmpty ? null : email.text.trim(), 'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'birthday': _date(birthday), 'anniversary': _date(anniversary), 'last_meaningful_interaction': _date(last), 'next_planned_interaction': _date(next),
        'interaction_notes': interaction.text.trim().isEmpty ? null : interaction.text.trim(), 'interests': interests.text.trim().isEmpty ? null : interests.text.trim(),
        'commitments': commitments.text.trim().isEmpty ? null : commitments.text.trim(), 'follow_up_items': followups.text.trim().isEmpty ? null : followups.text.trim(),
        'strengthening_goal': strengthening.text.trim().isEmpty ? null : strengthening.text.trim(), 'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
      };
      existing == null
          ? await _service.create(_endpoint, body)
          : await _service.update(_endpoint, int.parse(existing['id'].toString()), body);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      for (final c in [name,relation,email,phone,interaction,interests,commitments,followups,strengthening,notes]) { c.dispose(); }
    }
  }

  Future<void> _networkForm(Map<String, dynamic>? existing) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    bool aiLoading = false;
    final groups = TextEditingController(text: existing?['network_groups']?.toString() ?? '');
    final company = TextEditingController(text: existing?['company']?.toString() ?? '');
    final email = TextEditingController(text: existing?['email']?.toString() ?? '');
    final phone = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final met = TextEditingController(text: existing?['met_through']?.toString() ?? '');
    final opportunities = TextEditingController(text: existing?['opportunities']?.toString() ?? '');
    final actions = TextEditingController(text: existing?['action_points']?.toString() ?? '');
    final goal = TextEditingController(text: existing?['goal']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    String type = existing?['relationship_type']?.toString() ?? '';
    DateTime? last = DateTime.tryParse(existing?['last_contact_date']?.toString() ?? '');
    DateTime? next = DateTime.tryParse(existing?['next_follow_up_date']?.toString() ?? '');

    try {
      final save = await _scrollSheet(
        existing == null ? 'Add Network Contact' : 'Edit Network Contact',
        (context, setLocal) => [
          TextField(
            controller: name,
            onChanged: (_) => setLocal(() {}),
            decoration: const InputDecoration(labelText: 'Name *'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: type.isEmpty ? null : type,
            decoration: const InputDecoration(labelText: 'Connection Type *'),
            hint: const Text('Select connection type'),
            items: const [
              DropdownMenuItem(value:'business',child:Text('Business')),
              DropdownMenuItem(value:'career',child:Text('Career')),
              DropdownMenuItem(value:'investor',child:Text('Investor')),
              DropdownMenuItem(value:'mentor',child:Text('Mentor')),
              DropdownMenuItem(value:'friend',child:Text('Friend')),
              DropdownMenuItem(value:'community',child:Text('Community')),
              DropdownMenuItem(value:'association',child:Text('Professional association')),
              DropdownMenuItem(value:'client',child:Text('Client')),
              DropdownMenuItem(value:'partner',child:Text('Partner')),
              DropdownMenuItem(value:'other',child:Text('Other')),
            ],
            onChanged: (v) => setLocal(() => type = v ?? ''),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: groups,
            onChanged: (_) => setLocal(() {}),
            decoration: const InputDecoration(
              labelText: 'Networks / groups / topic',
              hintText: 'Business, Investors, Community',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'AI Generate',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add the person, connection type or network/topic above. AI prepares an editable draft without inventing contact details.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: aiLoading ||
                          (name.text.trim().isEmpty &&
                              groups.text.trim().isEmpty &&
                              type.isEmpty)
                      ? null
                      : () async {
                          final topic = groups.text.trim().isNotEmpty
                              ? groups.text.trim()
                              : name.text.trim().isNotEmpty
                                  ? name.text.trim()
                                  : type;

                          setLocal(() => aiLoading = true);
                          try {
                            final draft = await const AiFormAssistService().generate(
                              module: 'network-contacts',
                              topic: topic,
                              context: <String, dynamic>{
                                if (name.text.trim().isNotEmpty)
                                  'name': name.text.trim(),
                                if (type.isNotEmpty)
                                  'relationship_type': type,
                                if (groups.text.trim().isNotEmpty)
                                  'network_groups': groups.text.trim(),
                                if (company.text.trim().isNotEmpty)
                                  'company': company.text.trim(),
                                if (met.text.trim().isNotEmpty)
                                  'met_through': met.text.trim(),
                              },
                            );

                            void fill(
                              TextEditingController controller,
                              String key,
                            ) {
                              if (controller.text.trim().isEmpty &&
                                  draft[key] != null) {
                                controller.text = draft[key].toString();
                              }
                            }

                            fill(opportunities, 'opportunities');
                            fill(actions, 'action_points');
                            fill(goal, 'goal');
                            fill(notes, 'notes');

                            final extra = <String>[];
                            if (draft['follow_up_message'] != null) {
                              extra.add(
                                'Follow-up message: ${draft['follow_up_message']}',
                              );
                            }
                            if (draft['conversation_points'] != null) {
                              extra.add(
                                'Conversation points: ${draft['conversation_points']}',
                              );
                            }
                            if (notes.text.trim().isEmpty && extra.isNotEmpty) {
                              notes.text = extra.join('\n\n');
                            }

                            setLocal(() {});
                          } on ApiException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                          } finally {
                            setLocal(() => aiLoading = false);
                          }
                        },
                  icon: aiLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(aiLoading ? 'Generating...' : 'AI Generate'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 10),
          TextField(controller: company, decoration: const InputDecoration(labelText: 'Company / organisation')),
          const SizedBox(height: 10),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 10),
          TextField(controller: met, decoration: const InputDecoration(labelText: 'Where / how you met')),
          _dateTile(context, setLocal, 'Last contact', last, (v) => last = v),
          _dateTile(context, setLocal, 'Next follow-up', next, (v) => next = v),
          TextField(controller: opportunities, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Opportunities')),
          const SizedBox(height: 10),
          TextField(controller: actions, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Action points')),
          const SizedBox(height: 10),
          TextField(controller: goal, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Networking goal')),
          const SizedBox(height: 10),
          TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
        ],
      );
      if (save != true) return;

      if (name.text.trim().isEmpty || type.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add the person and select a connection type.'),
            ),
          );
        }
        return;
      }

      final body = {
        'name': name.text.trim(), 'relationship_type': type, 'network_groups': groups.text.trim().isEmpty ? null : groups.text.trim(),
        'company': company.text.trim().isEmpty ? null : company.text.trim(), 'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(), 'met_through': met.text.trim().isEmpty ? null : met.text.trim(),
        'last_contact_date': _date(last), 'next_follow_up_date': _date(next), 'opportunities': opportunities.text.trim().isEmpty ? null : opportunities.text.trim(),
        'action_points': actions.text.trim().isEmpty ? null : actions.text.trim(), 'goal': goal.text.trim().isEmpty ? null : goal.text.trim(),
        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
      };
      existing == null
          ? await _service.create(_endpoint, body)
          : await _service.update(_endpoint, int.parse(existing['id'].toString()), body);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      for (final c in [name,groups,company,email,phone,met,opportunities,actions,goal,notes]) { c.dispose(); }
    }
  }

  Future<bool?> _scrollSheet(
    String title,
    List<Widget> Function(BuildContext, StateSetter) fields,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .92, minChildSize: .65, maxChildSize: .97, expand: false,
        builder: (context, controller) => Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: StatefulBuilder(
            builder: (context, setLocal) => ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 28),
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  _relationships
                      ? 'Keep meaningful context so follow-up feels intentional, not transactional.'
                      : 'Organise connections by network and turn opportunities into clear follow-up actions.',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                ...fields(context, setLocal),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: () => Navigator.pop(sheetContext, true), icon: const Icon(Icons.save_outlined), label: const Text('Save')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile(BuildContext context, StateSetter setLocal, String label, DateTime? value, void Function(DateTime?) set) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(value == null ? 'Not set' : DateFormat('dd MMM yyyy').format(value)),
        trailing: Wrap(children: [
          if (value != null) IconButton(onPressed: () => setLocal(() => set(null)), icon: const Icon(Icons.clear_rounded)),
          IconButton(onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
            if (picked != null) setLocal(() => set(picked));
          }, icon: const Icon(Icons.calendar_month_outlined)),
        ]),
      );

  String? _date(DateTime? value) => value == null ? null : DateFormat('yyyy-MM-dd').format(value);

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(_relationships ? 'Relationships' : 'Networks'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _form(), icon: const Icon(Icons.add_rounded), label: Text(_relationships ? 'Add Person' : 'Add Contact')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          children: [
            Text(
              _relationships
                  ? 'Relationships helps you intentionally maintain important personal and professional relationships.'
                  : 'Networks helps you organise connections, opportunities and follow-ups across the communities you belong to.',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: _relationships ? 'Search people or relationship...' : 'Search people, company or network...',
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 12),
            if (_loading && _items.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _items.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 80), child: Text(_error!, textAlign: TextAlign.center))
            else if (rows.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [
                Icon(_relationships ? Icons.favorite_border_rounded : Icons.hub_outlined, size: 44),
                const SizedBox(height: 10),
                Text(_relationships ? 'No relationships yet' : 'No network contacts yet', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_relationships ? 'Add someone important and schedule your next intentional check-in.' : 'Add a connection and capture where you met, opportunities and the next follow-up.', textAlign: TextAlign.center),
              ])))
            else
              ...rows.map((item) {
                final last = _relationships ? item['last_meaningful_interaction'] : item['last_contact_date'];
                final next = _relationships ? item['next_planned_interaction'] : item['next_follow_up_date'];
                final days = _daysSince(last);
                return Card(
                  child: ListTile(
                    onTap: () => _form(item),
                    leading: CircleAvatar(child: Icon(_relationships ? Icons.favorite_outline_rounded : Icons.person_outline_rounded)),
                    title: Text((item['name'] ?? 'Person').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([
                      (_relationships ? item['category'] : item['network_groups'] ?? item['relationship_type'])?.toString(),
                      if (days != null) '$days day${days == 1 ? '' : 's'} since last contact',
                      if (next != null) 'Next: $next',
                    ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
