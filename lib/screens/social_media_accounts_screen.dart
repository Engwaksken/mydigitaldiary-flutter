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

  final _whatsApp = TextEditingController();
  final _channelName = TextEditingController();
  final _channelUrl = TextEditingController();

  List<Map<String, dynamic>> _accounts = <Map<String, dynamic>>[];

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
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final data = await _service.profileAccounts();

      final whatsapp = data['whatsapp'] is Map
          ? Map<String, dynamic>.from(
              data['whatsapp'] as Map,
            )
          : <String, dynamic>{};

      final rawAccounts = data['accounts'];

      final accounts = rawAccounts is List
          ? rawAccounts
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _whatsApp.text =
            (whatsapp['number'] ?? '').toString();

        _channelName.text =
            (whatsapp['channel_name'] ?? '').toString();

        _channelUrl.text =
            (whatsapp['channel_url'] ?? '').toString();

        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showMessage(
        'Could not load social media settings: $e',
      );
    }
  }

  Future<void> _saveWhatsApp() async {
    if (_savingWhatsApp) return;

    setState(() => _savingWhatsApp = true);

    try {
      await _service.saveWhatsApp(
        number: _whatsApp.text.trim(),
        channelName: _channelName.text.trim(),
        channelUrl: _channelUrl.text.trim(),
      );

      if (!mounted) return;

      _showMessage('WhatsApp settings saved.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not save WhatsApp settings: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _savingWhatsApp = false);
      }
    }
  }

  Future<void> _configureAutomaticPublishing(
    Map<String, dynamic> account,
  ) async {
    final id = _accountId(account);

    if (id == null) {
      _showMessage(
        'This social media account has an invalid ID.',
      );
      return;
    }

    bool enabled = _asBool(
      account['auto_publish_enabled'],
    );

    final externalAccountId = TextEditingController(
      text: (account['external_account_id'] ?? '')
          .toString(),
    );

    final accessToken = TextEditingController();

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              final platform =
                  _platformLabel(account['platform']);

              final connected =
                  _asBool(account['is_connected']);

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  4,
                  18,
                  MediaQuery.viewInsetsOf(context)
                          .bottom +
                      24,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Automatic Posting · $platform',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Authorise this account for automatic publishing. '
                      'Access tokens are sent securely to Laravel and should '
                      'be stored encrypted. Saved tokens are never shown again.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: connected
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFFFBEB),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            connected
                                ? Icons.verified_outlined
                                : Icons.info_outline,
                            size: 20,
                            color: connected
                                ? const Color(0xFF047857)
                                : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              connected
                                  ? 'This account is already connected. You can update its publishing settings or replace its OAuth token.'
                                  : 'This account is not yet fully authorised for automatic publishing.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: connected
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      title: const Text(
                        'Enable automatic posting',
                      ),
                      subtitle: const Text(
                        'Scheduled posts can publish automatically when the platform account has authorised publishing access.',
                      ),
                      onChanged: (value) {
                        setLocal(() => enabled = value);
                      },
                    ),

                    const SizedBox(height: 6),

                    TextField(
                      controller: externalAccountId,
                      decoration: InputDecoration(
                        labelText:
                            _externalIdLabel(account['platform']),
                        hintText:
                            'Provider account/page/channel ID',
                        border:
                            const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: accessToken,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: connected
                            ? 'Replace OAuth access token (optional)'
                            : 'OAuth access token',
                        helperText:
                            _tokenHelper(account['platform']),
                        helperMaxLines: 3,
                        border:
                            const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, true),
                      icon:
                          const Icon(Icons.schedule_send),
                      label:
                          const Text('Save Automatic Posting'),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (saved != true) return;

      await _service.updateAutomaticPublishing(
        accountId: id,
        enabled: enabled,
        externalAccountId:
            externalAccountId.text.trim(),
        accessToken:
            accessToken.text.trim().isEmpty
                ? null
                : accessToken.text.trim(),
      );

      if (!mounted) return;

      _showMessage(
        enabled
            ? 'Automatic posting settings saved.'
            : 'Automatic posting disabled.',
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not update automatic posting: $e',
      );
    } finally {
      externalAccountId.dispose();
      accessToken.dispose();
    }
  }

  Future<void> _addAccount() async {
    String platform = 'instagram';

    final name = TextEditingController();
    final username = TextEditingController();

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  4,
                  18,
                  MediaQuery.viewInsetsOf(context)
                          .bottom +
                      24,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add Social Media Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add an account identity first. You can configure automatic publishing after saving it.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: platform,
                      decoration: const InputDecoration(
                        labelText: 'Platform',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'instagram',
                          child: Text('Instagram'),
                        ),
                        DropdownMenuItem(
                          value: 'facebook',
                          child: Text('Facebook'),
                        ),
                        DropdownMenuItem(
                          value: 'x',
                          child: Text('X (Twitter)'),
                        ),
                        DropdownMenuItem(
                          value: 'tiktok',
                          child: Text('TikTok'),
                        ),
                        DropdownMenuItem(
                          value: 'linkedin',
                          child: Text('LinkedIn'),
                        ),
                        DropdownMenuItem(
                          value: 'youtube',
                          child: Text('YouTube'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setLocal(
                            () => platform = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Account name',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: username,
                      decoration: InputDecoration(
                        labelText:
                            _usernameLabel(platform),
                        border:
                            const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    FilledButton.icon(
                      onPressed: () {
                        if (name.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter the account name.',
                                ),
                              ),
                            );
                          return;
                        }

                        Navigator.pop(context, true);
                      },
                      icon: const Icon(Icons.add),
                      label:
                          const Text('Add Account'),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (saved != true) return;

      await _service.addAccount(
        platform: platform,
        accountName: name.text.trim(),
        username: username.text.trim(),
      );

      if (!mounted) return;

      _showMessage('Social media account added.');

      await _load();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not add account: $e',
      );
    } finally {
      name.dispose();
      username.dispose();
    }
  }

  Future<void> _remove(
    Map<String, dynamic> account,
  ) async {
    final id = _accountId(account);

    if (id == null) {
      _showMessage(
        'This social media account has an invalid ID.',
      );
      return;
    }

    final accountName =
        (account['account_name'] ?? 'This account')
            .toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Remove social media account?'),
          content: Text(
            '$accountName will be removed from your profile. '
            'Scheduled posts using this account may require another publishing destination.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await _service.removeAccount(id);

      if (!mounted) return;

      _showMessage('Social media account removed.');

      await _load();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not remove account: $e',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  int? _accountId(Map<String, dynamic> account) {
    final raw = account['id'];

    if (raw is int) return raw;

    return int.tryParse(raw?.toString() ?? '');
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text =
        value?.toString().trim().toLowerCase();

    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'enabled';
  }

  static String _platformLabel(dynamic platform) {
    switch (
        platform?.toString().trim().toLowerCase()) {
      case 'instagram':
        return 'Instagram';
      case 'facebook':
        return 'Facebook';
      case 'x':
      case 'twitter':
        return 'X (Twitter)';
      case 'tiktok':
        return 'TikTok';
      case 'linkedin':
        return 'LinkedIn';
      case 'youtube':
        return 'YouTube';
      default:
        return platform?.toString().trim().isNotEmpty ==
                true
            ? platform.toString()
            : 'Social Media';
    }
  }

  static String _usernameLabel(String platform) {
    switch (platform) {
      case 'youtube':
        return 'Channel name / handle';
      case 'facebook':
        return 'Page username / handle';
      case 'linkedin':
        return 'Page / profile handle';
      default:
        return 'Username / handle';
    }
  }

  String _externalIdLabel(dynamic platform) {
    switch (
        platform?.toString().trim().toLowerCase()) {
      case 'facebook':
        return 'Facebook Page ID (optional)';
      case 'instagram':
        return 'Instagram Business Account ID (optional)';
      case 'x':
      case 'twitter':
        return 'X User ID (optional)';
      case 'linkedin':
        return 'LinkedIn organisation/person ID (optional)';
      case 'youtube':
        return 'YouTube Channel ID (optional)';
      default:
        return 'Provider account ID (optional)';
    }
  }

  String _tokenHelper(dynamic platform) {
    switch (
        platform?.toString().trim().toLowerCase()) {
      case 'x':
      case 'twitter':
        return 'Use a user-context OAuth token that has permission to create posts.';
      case 'instagram':
        return 'Use an authorised token for the connected Instagram professional account.';
      case 'facebook':
        return 'Use an authorised token with access to the selected Facebook Page.';
      case 'linkedin':
        return 'Use an authorised LinkedIn token with the required posting permission.';
      case 'youtube':
        return 'Use an authorised Google/YouTube OAuth token with channel publishing permission.';
      default:
        return 'Enter a valid OAuth access token issued for this account.';
    }
  }

  IconData _platformIcon(dynamic platform) {
    switch (
        platform?.toString().trim().toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'youtube':
        return Icons.play_circle_outline;
      case 'linkedin':
        return Icons.business_center_outlined;
      case 'tiktok':
        return Icons.music_note_outlined;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'x':
      case 'twitter':
        return Icons.alternate_email;
      default:
        return Icons.public;
    }
  }

  Widget _statusChip({
    required String label,
    required bool active,
    required IconData icon,
  }) {
    final background = active
        ? const Color(0xFFECFDF5)
        : const Color(0xFFF8FAFC);

    final foreground = active
        ? const Color(0xFF047857)
        : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(
    Map<String, dynamic> account,
  ) {
    final connected = _asBool(
      account['is_connected'],
    );

    final automatic = _asBool(
      account['auto_publish_enabled'],
    );

    final platform =
        _platformLabel(account['platform']);

    final accountName =
        (account['account_name'] ?? '').toString();

    final username =
        (account['username'] ?? '').toString().trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          14,
          8,
          12,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(
                    _platformIcon(
                      account['platform'],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        accountName.isEmpty
                            ? platform
                            : accountName,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        username.isEmpty
                            ? platform
                            : '$platform · $username',
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Account actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'automatic':
                        _configureAutomaticPublishing(
                          account,
                        );
                        break;
                      case 'remove':
                        _remove(account);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'automatic',
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            EdgeInsets.zero,
                        leading: Icon(
                          Icons.schedule_send_outlined,
                        ),
                        title: Text(
                          'Automatic Posting',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline,
                        ),
                        title:
                            Text('Remove Account'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _statusChip(
                  label: connected
                      ? 'Connected'
                      : 'Not connected',
                  active: connected,
                  icon: connected
                      ? Icons.verified_outlined
                      : Icons.link_off_outlined,
                ),
                _statusChip(
                  label: automatic
                      ? 'Auto posting on'
                      : 'Auto posting off',
                  active: automatic,
                  icon:
                      Icons.schedule_send_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _configureAutomaticPublishing(
                  account,
                ),
                icon: const Icon(
                  Icons.settings_outlined,
                ),
                label: Text(
                  automatic
                      ? 'Manage Automatic Posting'
                      : 'Set Up Automatic Posting',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen =
        MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Social Media Settings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: keyboardOpen
          ? null
          : FloatingActionButton.extended(
              onPressed: _addAccount,
              icon: const Icon(Icons.add),
              label: const Text('Add Account'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            100,
          ),
          children: [
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2,
              ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chat_outlined),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WhatsApp',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Set the number used for Status sharing and your WhatsApp Channel details.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _whatsApp,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'WhatsApp number',
                        hintText:
                            '+2567XXXXXXXX',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _channelName,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'WhatsApp Channel name',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _channelUrl,
                      keyboardType:
                          TextInputType.url,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'WhatsApp Channel link',
                        hintText:
                            'https://whatsapp.com/channel/...',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    FilledButton.icon(
                      onPressed:
                          _savingWhatsApp
                              ? null
                              : _saveWhatsApp,
                      icon: _savingWhatsApp
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.save_outlined,
                            ),
                      label: Text(
                        _savingWhatsApp
                            ? 'Saving...'
                            : 'Save WhatsApp Settings',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Social Media Accounts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Manage account identities and automatic publishing.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add account',
                  onPressed: _addAccount,
                  icon:
                      const Icon(Icons.add_circle_outline),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (!_loading && _accounts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.alternate_email_rounded,
                        size: 38,
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'No social media accounts saved',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add Instagram, Facebook, X, TikTok, LinkedIn or YouTube, then configure automatic posting where supported.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _addAccount,
                        icon:
                            const Icon(Icons.add),
                        label: const Text(
                          'Add Account',
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
