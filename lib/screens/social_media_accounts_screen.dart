import 'package:flutter/material.dart';

import '../services/social_media_planner_service.dart';

class SocialMediaAccountsScreen extends StatefulWidget {
  const SocialMediaAccountsScreen({super.key});

  @override
  State<SocialMediaAccountsScreen> createState() => _SocialMediaAccountsScreenState();
}

class _SocialMediaAccountsScreenState extends State<SocialMediaAccountsScreen> {
  final _service = const SocialMediaPlannerService();
  final _whatsApp = TextEditingController();
  final _channelName = TextEditingController();
  final _channelUrl = TextEditingController();
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  bool _savingWhatsApp = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _whatsApp.dispose();
    _channelName.dispose();
    _channelUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await _service.profileAccounts();
      final whatsapp = data['whatsapp'] is Map
          ? Map<String, dynamic>.from(data['whatsapp'] as Map)
          : <String, dynamic>{};
      final raw = data['accounts'];
      final accounts = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _whatsApp.text = (whatsapp['number'] ?? '').toString();
        _channelName.text = (whatsapp['channel_name'] ?? '').toString();
        _channelUrl.text = (whatsapp['channel_url'] ?? '').toString();
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load social media settings: $e')),
      );
    }
  }

  Future<void> _saveWhatsApp() async {
    if (_savingWhatsApp) return;
    setState(() => _savingWhatsApp = true);
    try {
      await _service.saveWhatsApp(
        number: _whatsApp.text,
        channelName: _channelName.text,
        channelUrl: _channelUrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp settings saved.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save WhatsApp settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingWhatsApp = false);
    }
  }


  Future<void> _configureAutomaticPublishing(
    Map<String, dynamic> account,
  ) async {
    final idRaw = account['id'];
    final id = idRaw is int
        ? idRaw
        : int.tryParse(idRaw?.toString() ?? '');

    if (id == null) return;

    bool enabled =
        account['auto_publish_enabled'] == true ||
        account['auto_publish_enabled'] == 1 ||
        account['auto_publish_enabled']?.toString() == '1';

    final externalAccountId = TextEditingController(
      text: (account['external_account_id'] ?? '').toString(),
    );
    final accessToken = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Automatic Posting · ${(account['platform'] ?? '').toString().toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Automatic posting requires an authorised provider account. Access tokens are sent to Laravel and stored encrypted; the app never displays a saved token again.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  title: const Text('Enable automatic posting'),
                  subtitle: const Text(
                    'Scheduled posts can publish automatically without opening the phone app when this platform has authorised publishing access.',
                  ),
                  onChanged: (value) {
                    setLocal(() => enabled = value);
                  },
                ),
                TextField(
                  controller: externalAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Provider account ID (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accessToken,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: account['is_connected'] == 1 ||
                            account['is_connected'] == true
                        ? 'Replace OAuth access token (optional)'
                        : 'OAuth access token',
                    helperText:
                        'For X posting, use a user-context token with tweet.write permission.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save Automatic Posting'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      await _service.updateAutomaticPublishing(
        accountId: id,
        enabled: enabled,
        externalAccountId: externalAccountId.text,
        accessToken: accessToken.text.isEmpty
            ? null
            : accessToken.text,
      );

      await _load();
    }

    externalAccountId.dispose();
    accessToken.dispose();
  }

  Future<void> _addAccount() async {
    String platform = 'instagram';
    final name = TextEditingController();
    final username = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add Social Media Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: platform,
                  decoration: const InputDecoration(labelText: 'Platform'),
                  items: const [
                    DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
                    DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
                    DropdownMenuItem(value: 'x', child: Text('X (Twitter)')),
                    DropdownMenuItem(value: 'tiktok', child: Text('TikTok')),
                    DropdownMenuItem(value: 'linkedin', child: Text('LinkedIn')),
                  ],
                  onChanged: (value) {
                    if (value != null) setLocal(() => platform = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Account name')),
                const SizedBox(height: 10),
                TextField(controller: username, decoration: const InputDecoration(labelText: 'Username / handle')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter the account name.')),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Add Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      try {
        await _service.addAccount(
          platform: platform,
          accountName: name.text,
          username: username.text,
        );
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add account: $e')),
          );
        }
      }
    }

    name.dispose();
    username.dispose();
  }

  Future<void> _remove(Map<String, dynamic> account) async {
    final id = account['id'] is int
        ? account['id'] as int
        : int.tryParse(account['id']?.toString() ?? '');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove social media account?'),
        content: Text('${account['account_name'] ?? 'This account'} will be removed from your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.removeAccount(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Social Media Settings')),
      floatingActionButton: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _addAccount,
              icon: const Icon(Icons.add),
              label: const Text('Add Account'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chat_outlined),
                        SizedBox(width: 8),
                        Text('WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Set the number used for Status sharing and your WhatsApp Channel details.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _whatsApp,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'WhatsApp number', hintText: '+2567XXXXXXXX'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _channelName, decoration: const InputDecoration(labelText: 'WhatsApp Channel name')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _channelUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'WhatsApp Channel link', hintText: 'https://whatsapp.com/channel/...'),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _savingWhatsApp ? null : _saveWhatsApp,
                      icon: _savingWhatsApp
                          ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save WhatsApp Settings'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Social Media Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Save your Instagram, Facebook, TikTok and LinkedIn identities. Official publishing authorisation remains separate.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            if (!_loading && _accounts.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.alternate_email_rounded),
                  title: Text('No social media accounts saved'),
                  subtitle: Text('Tap Add Account to add your first account.'),
                ),
              )
            else
              ..._accounts.map((account) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.alternate_email_rounded)),
                  title: Text('${account['platform'] ?? ''} · ${account['account_name'] ?? ''}'),
                  subtitle: Text((account['username'] ?? '').toString().isEmpty ? 'No username saved' : account['username'].toString()),
                  trailing: IconButton(
                    tooltip: 'Remove account',
                    onPressed: () => _remove(account),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }
}
