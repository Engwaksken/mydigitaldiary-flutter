import 'package:flutter/material.dart';

import '../services/social_media_planner_service.dart';

class SocialMediaAccountsScreen extends StatefulWidget {
  const SocialMediaAccountsScreen({super.key});

  @override
  State<SocialMediaAccountsScreen> createState() =>
      _SocialMediaAccountsScreenState();
}

class _SocialMediaAccountsScreenState
    extends State<SocialMediaAccountsScreen> {
  final _service = const SocialMediaPlannerService();

  List<Map<String, dynamic>> _accounts = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  static const Map<String, String> _platformLabels = {
    'instagram': 'Instagram',
    'facebook': 'Facebook',
    'x': 'X (Twitter)',
    'tiktok': 'TikTok',
    'linkedin': 'LinkedIn',
    'whatsapp_status': 'WhatsApp Status',
    'whatsapp_channel': 'WhatsApp Channel',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _truthy(dynamic value) {
    return value == true ||
        value == 1 ||
        value?.toString().toLowerCase() == 'true' ||
        value?.toString() == '1';
  }

  String _platformLabel(String platform) {
    return _platformLabels[platform] ??
        platform
            .replaceAll('_', ' ')
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map(
              (part) =>
                  '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
            )
            .join(' ');
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      // IMPORTANT:
      // This is intentionally ONE API call.
      //
      // The existing My Digital Diary API already uses:
      // GET /api/profile/social-media
      //
      // Laravel now includes safe provider availability in the same
      // response. Mobile never requests provider API keys, secrets,
      // base URLs or webhook credentials.
      final data = await _service.profileAccounts();

      final rawAccounts = data['accounts'];
      final accounts = rawAccounts is List
          ? rawAccounts
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _showAddAccountSheet() async {
    var platform = 'instagram';

    final accountName = TextEditingController();
    final username = TextEditingController();
    final externalAccountId = TextEditingController();
    final providerAccountRef = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final isWhatsApp =
                platform == 'whatsapp_status' ||
                platform == 'whatsapp_channel';

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                4,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add Social Media Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'My Digital Diary administrators manage provider APIs and credentials. You only add your account details.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: platform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                    ),
                    items: _platformLabels.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocal(() => platform = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accountName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Account name',
                      hintText: 'e.g. My Business',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username / handle',
                      hintText: '@username',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: externalAccountId,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: platform == 'whatsapp_channel'
                          ? 'WhatsApp Channel ID'
                          : 'Platform account ID',
                      hintText: isWhatsApp
                          ? 'Only if your provider requires it'
                          : 'Page/Profile/Author ID if required',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: providerAccountRef,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText:
                          'Provider session / account reference',
                      hintText: isWhatsApp
                          ? 'e.g. your WhatsScale / WAHA session'
                          : 'Only when required by the configured provider',
                      helperText: isWhatsApp
                          ? 'For automatic WhatsApp posting, use the session connected to your WhatsApp account.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      if (accountName.text.trim().isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter the account name before saving.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Account'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      setState(() => _saving = true);

      try {
        await _service.addAccount(
          platform: platform,
          accountName: accountName.text,
          username: username.text,
          externalAccountId: externalAccountId.text,
          providerAccountRef: providerAccountRef.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Social media account added.'),
            ),
          );
        }

        await _load();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not add account: $error',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    accountName.dispose();
    username.dispose();
    externalAccountId.dispose();
    providerAccountRef.dispose();
  }

  Future<void> _configureAutomaticPublishing(
    Map<String, dynamic> account,
  ) async {
    final id = account['id'] is int
        ? account['id'] as int
        : int.tryParse((account['id'] ?? '').toString());

    if (id == null) return;

    final platform = (account['platform'] ?? '').toString();
    final providerAvailable =
        _truthy(account['automatic_api_available']);

    if (!providerAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Automatic posting for ${_platformLabel(platform)} is not enabled by the administrator.',
          ),
        ),
      );
      return;
    }

    var enabled = _truthy(account['auto_publish_enabled']);

    final externalAccountId = TextEditingController(
      text: (account['external_account_id'] ?? '').toString(),
    );
    final providerAccountRef = TextEditingController(
      text: (account['provider_account_ref'] ?? '').toString(),
    );

    final providerName =
        (account['automatic_provider_name'] ?? 'Configured provider')
            .toString();
    final requiresOAuth =
        (account['automatic_connection_mode'] ?? '').toString() ==
            'user_oauth';
    final isWhatsApp =
        platform == 'whatsapp_status' ||
        platform == 'whatsapp_channel';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                4,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_platformLabel(platform)} Automatic Posting',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          color: Color(0xFF047857),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '$providerName is enabled by the administrator.',
                            style: const TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (requiresOAuth) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'The administrator manages the application/API credentials, but this platform still requires you to authorise your own social account.',
                        style: TextStyle(
                          color: Color(0xFF1E40AF),
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: externalAccountId,
                    decoration: InputDecoration(
                      labelText: platform == 'whatsapp_channel'
                          ? 'WhatsApp Channel ID'
                          : 'Platform account ID',
                      hintText: isWhatsApp
                          ? 'Channel/account ID if required'
                          : 'Page/Profile/Author ID if required',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: providerAccountRef,
                    decoration: InputDecoration(
                      labelText:
                          'Provider session / account reference',
                      hintText: isWhatsApp
                          ? 'Your WhatsScale / WAHA session'
                          : 'Only if the provider requires it',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    title: const Text(
                      'Enable automatic posting',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Scheduled posts can publish automatically when this account is ready.',
                    ),
                    onChanged: (value) {
                      setLocal(() => enabled = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Automatic Posting'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      setState(() => _saving = true);

      try {
        await _service.updateAutomaticPublishing(
          accountId: id,
          enabled: enabled,
          externalAccountId: externalAccountId.text,
          providerAccountRef: providerAccountRef.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Automatic posting settings updated.',
              ),
            ),
          );
        }

        await _load();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not update automatic posting: $error',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    externalAccountId.dispose();
    providerAccountRef.dispose();
  }

  Future<void> _removeAccount(
    Map<String, dynamic> account,
  ) async {
    final id = account['id'] is int
        ? account['id'] as int
        : int.tryParse((account['id'] ?? '').toString());

    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove social account?'),
          content: Text(
            'Remove ${(account['account_name'] ?? 'this account').toString()} from My Digital Diary?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.removeAccount(id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not remove account: $error',
            ),
          ),
        );
      }
    }
  }

  IconData _platformIcon(String platform) {
    return switch (platform) {
      'facebook' => Icons.facebook_rounded,
      'instagram' => Icons.camera_alt_outlined,
      'x' => Icons.alternate_email_rounded,
      'tiktok' => Icons.music_note_rounded,
      'linkedin' => Icons.work_outline_rounded,
      'whatsapp_status' => Icons.chat_bubble_outline_rounded,
      'whatsapp_channel' => Icons.campaign_outlined,
      _ => Icons.public_rounded,
    };
  }

  Widget _accountCard(Map<String, dynamic> account) {
    final platform = (account['platform'] ?? '').toString();
    final providerAvailable =
        _truthy(account['automatic_api_available']);
    final autoEnabled =
        _truthy(account['auto_publish_enabled']);
    final providerName =
        (account['automatic_provider_name'] ?? '').toString().trim();
    final username =
        (account['username'] ?? '').toString().trim();
    final session =
        (account['provider_account_ref'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Icon(_platformIcon(platform)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_platformLabel(platform)} · ${account['account_name'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          username.isEmpty
                              ? 'No username saved'
                              : username,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                        if (session.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Session: $session',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove account',
                    onPressed: () => _removeAccount(account),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _StatusChip(
                    icon: providerAvailable
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    text: providerAvailable
                        ? '${providerName.isEmpty ? 'API' : providerName} available'
                        : 'Automatic API unavailable',
                    positive: providerAvailable,
                  ),
                  _StatusChip(
                    icon: autoEnabled
                        ? Icons.bolt_rounded
                        : Icons.schedule_rounded,
                    text: autoEnabled
                        ? 'Automatic posting ON'
                        : 'Automatic posting OFF',
                    positive: autoEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: providerAvailable && !_saving
                    ? () => _configureAutomaticPublishing(
                          account,
                        )
                    : null,
                icon: const Icon(
                  Icons.settings_suggest_outlined,
                ),
                label: Text(
                  providerAvailable
                      ? 'Automatic Posting'
                      : 'Admin API Not Enabled',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Media Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton:
          MediaQuery.viewInsetsOf(context).bottom > 0
              ? null
              : FloatingActionButton.extended(
                  onPressed:
                      _saving ? null : _showAddAccountSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Account'),
                ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'My Digital Diary administrators securely manage social-media API providers and credentials. You only provide your account, Page/Profile/Channel ID, or provider session when required.',
                      style: TextStyle(
                        color: Color(0xFF1E40AF),
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding:
                    EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 38,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load social media accounts.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(
                          Icons.refresh_rounded,
                        ),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_accounts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.share_outlined,
                        size: 38,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No social media accounts yet.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Tap Add Account to add your first social profile or WhatsApp session.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._accounts.map(_accountCard),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.text,
    required this.positive,
  });

  final IconData icon;
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final background =
        positive
            ? const Color(0xFFECFDF5)
            : const Color(0xFFF1F5F9);
    final foreground =
        positive
            ? const Color(0xFF047857)
            : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
