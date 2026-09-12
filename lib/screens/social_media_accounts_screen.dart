import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/social_media_planner_service.dart';

class SocialMediaAccountsScreen extends StatefulWidget {
  const SocialMediaAccountsScreen({super.key});

  @override
  State<SocialMediaAccountsScreen> createState() =>
      _SocialMediaAccountsScreenState();
}

class _SocialMediaAccountsScreenState extends State<SocialMediaAccountsScreen> {
  final SocialMediaPlannerService _service = const SocialMediaPlannerService();

  final TextEditingController _whatsApp = TextEditingController();
  final TextEditingController _channelName = TextEditingController();
  final TextEditingController _channelUrl = TextEditingController();

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

  bool _truthy(dynamic value) {
    return value == true || value == 1 || value?.toString() == '1';
  }

  int? _accountId(Map<String, dynamic> account) {
    final raw = account['id'];

    if (raw is int) {
      return raw;
    }

    return int.tryParse(raw?.toString() ?? '');
  }

  String _platformLabel(dynamic value) {
    final platform = value?.toString().trim().toLowerCase() ?? '';

    switch (platform) {
      case 'x':
      case 'twitter':
        return 'X';
      case 'facebook':
        return 'Facebook';
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'linkedin':
        return 'LinkedIn';
      case 'youtube':
        return 'YouTube';
      default:
        if (platform.isEmpty) {
          return 'Social Media';
        }

        return platform[0].toUpperCase() + platform.substring(1);
    }
  }

  IconData _platformIcon(dynamic value) {
    final platform = value?.toString().trim().toLowerCase() ?? '';

    switch (platform) {
      case 'x':
      case 'twitter':
        return Icons.close_rounded;
      case 'facebook':
        return Icons.facebook_rounded;
      case 'youtube':
        return Icons.play_circle_outline_rounded;
      case 'linkedin':
        return Icons.work_outline_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      case 'instagram':
        return Icons.photo_camera_outlined;
      default:
        return Icons.alternate_email_rounded;
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                (account) => Map<String, dynamic>.from(account),
              )
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _whatsApp.text = (whatsapp['number'] ?? '').toString();
        _channelName.text = (whatsapp['channel_name'] ?? '').toString();
        _channelUrl.text = (whatsapp['channel_url'] ?? '').toString();
        _accounts = accounts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loading = false);

      _showMessage(
        'Could not load social media settings: $error',
        error: true,
      );
    }
  }

  Future<void> _saveWhatsApp() async {
    if (_savingWhatsApp) {
      return;
    }

    setState(() => _savingWhatsApp = true);

    try {
      await _service.saveWhatsApp(
        number: _whatsApp.text.trim(),
        channelName: _channelName.text.trim(),
        channelUrl: _channelUrl.text.trim(),
      );

      _showMessage('WhatsApp settings saved.');
    } catch (error) {
      _showMessage(
        'Could not save WhatsApp settings: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _savingWhatsApp = false);
      }
    }
  }

  Future<void> _saveAutomaticPublishing({
    required int accountId,
    required bool enabled,
    required String externalAccountId,
    required String accessToken,
  }) async {
    final body = <String, dynamic>{
      'auto_publish_enabled': enabled,
      'external_account_id':
          externalAccountId.trim().isEmpty ? null : externalAccountId.trim(),
    };

    final token = accessToken.trim();

    if (token.isNotEmpty) {
      body['access_token'] = token;
    }

    // Call ApiClient directly here so this screen remains compatible
    // with older SocialMediaPlannerService versions that do not yet
    // declare an accessToken named parameter.
    await ApiClient.instance.put(
      'profile/social-media/accounts/$accountId/'
      'automatic-publishing',
      body,
    );
  }

  Future<void> _configureAutomaticPublishing(
    Map<String, dynamic> account,
  ) async {
    final id = _accountId(account);

    if (id == null) {
      _showMessage(
        'This social media account has an invalid ID.',
        error: true,
      );
      return;
    }

    bool enabled = _truthy(
      account['auto_publish_enabled'],
    );

    final externalAccountId = TextEditingController(
      text: (account['external_account_id'] ?? '').toString(),
    );

    final accessToken = TextEditingController();

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return SafeArea(
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
                        'Automatic Posting · '
                        '${_platformLabel(account['platform'])}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Automatic posting requires an authorised '
                        'provider account. Tokens are sent securely '
                        'to Laravel and are not displayed again.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: enabled,
                        title: const Text(
                          'Enable automatic posting',
                        ),
                        subtitle: const Text(
                          'Scheduled posts can publish '
                          'automatically when this account has '
                          'authorised provider access.',
                        ),
                        onChanged: (value) {
                          setLocal(() {
                            enabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 4),
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
                          labelText: _truthy(account['is_connected'])
                              ? 'Replace OAuth access token '
                                  '(optional)'
                              : 'OAuth access token',
                          helperText: _platformLabel(account['platform']) == 'X'
                              ? 'For X automatic posting, use '
                                  'a user-context token with '
                                  'write permission.'
                              : 'Leave blank to keep the '
                                  'currently saved token.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                            true,
                          );
                        },
                        icon: const Icon(
                          Icons.cloud_upload_outlined,
                        ),
                        label: const Text(
                          'Save Automatic Posting',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (saved != true) {
        return;
      }

      await _saveAutomaticPublishing(
        accountId: id,
        enabled: enabled,
        externalAccountId: externalAccountId.text,
        accessToken: accessToken.text,
      );

      _showMessage(
        enabled
            ? 'Automatic posting settings saved.'
            : 'Automatic posting disabled.',
      );

      await _load();
    } catch (error) {
      _showMessage(
        'Could not update automatic posting: $error',
        error: true,
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
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return SafeArea(
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
                      const Text(
                        'Add Social Media Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: platform,
                        decoration: const InputDecoration(
                          labelText: 'Platform',
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
                            child: Text('X'),
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
                          if (value == null) {
                            return;
                          }

                          setLocal(() {
                            platform = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Account name',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: username,
                        decoration: const InputDecoration(
                          labelText: 'Username / handle',
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () {
                          if (name.text.trim().isEmpty) {
                            _showMessage(
                              'Enter the account name.',
                              error: true,
                            );
                            return;
                          }

                          Navigator.pop(
                            sheetContext,
                            true,
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Account'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (saved != true) {
        return;
      }

      await _service.addAccount(
        platform: platform,
        accountName: name.text.trim(),
        username: username.text.trim(),
      );

      _showMessage('Social media account added.');
      await _load();
    } catch (error) {
      _showMessage(
        'Could not add account: $error',
        error: true,
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
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove social media account?',
          ),
          content: Text(
            '${account['account_name'] ?? 'This account'} '
            'will be removed from your profile.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.removeAccount(id);
      _showMessage('Social media account removed.');
      await _load();
    } catch (error) {
      _showMessage(
        'Could not remove account: $error',
        error: true,
      );
    }
  }

  Widget _whatsAppCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.chat_outlined),
                SizedBox(width: 8),
                Text(
                  'WhatsApp',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Set the number used for Status sharing and '
              'your WhatsApp Channel details.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsApp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                hintText: '+2567XXXXXXXX',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _channelName,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Channel name',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _channelUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Channel link',
                hintText: 'https://whatsapp.com/channel/...',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _savingWhatsApp ? null : _saveWhatsApp,
              icon: _savingWhatsApp
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text(
                'Save WhatsApp Settings',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(
    Map<String, dynamic> account,
  ) {
    final automatic = _truthy(account['auto_publish_enabled']);
    final connected = _truthy(account['is_connected']);

    final username = (account['username'] ?? '').toString().trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(
              _platformIcon(account['platform']),
            ),
          ),
          title: Text(
            '${_platformLabel(account['platform'])} · '
            '${account['account_name'] ?? ''}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(
                username.isEmpty ? 'No username saved' : username,
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _statusChip(
                    connected ? 'Connected' : 'Not connected',
                    connected ? Icons.link_rounded : Icons.link_off_rounded,
                  ),
                  _statusChip(
                    automatic ? 'Auto posting on' : 'Auto posting off',
                    automatic
                        ? Icons.auto_awesome_rounded
                        : Icons.schedule_send_outlined,
                  ),
                ],
              ),
            ],
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            tooltip: 'Account actions',
            onSelected: (value) {
              if (value == 'automatic') {
                _configureAutomaticPublishing(
                  account,
                );
              } else if (value == 'remove') {
                _remove(account);
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'automatic',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
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
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline_rounded,
                    ),
                    title: Text('Remove'),
                  ),
                ),
              ];
            },
          ),
        ),
      ),
    );
  }

  Widget _statusChip(
    String label,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: const Color(0xFF475569),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Social Media Settings',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            100,
          ),
          children: [
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2,
              ),
            const SizedBox(height: 12),
            _whatsAppCard(),
            const SizedBox(height: 18),
            const Text(
              'Social Media Accounts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage Instagram, Facebook, X, TikTok, '
              'LinkedIn and YouTube accounts. Use the '
              'account menu to configure automatic posting.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            if (!_loading && _accounts.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.alternate_email_rounded,
                  ),
                  title: Text(
                    'No social media accounts saved',
                  ),
                  subtitle: Text(
                    'Tap Add Account to add your '
                    'first account.',
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
