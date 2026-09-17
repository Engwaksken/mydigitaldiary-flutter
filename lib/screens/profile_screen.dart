import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/branding_service.dart';
import '../services/profile_service.dart';
import '../services/sync_status_service.dart';
import 'api_keys_screen.dart';
import 'appearance_screen.dart';
import 'edit_profile_screen.dart';
import 'organization_screen.dart';
import 'subscription_screen.dart';
import 'personalisation_screen.dart';
import 'monthly_review_screen.dart';
import 'offline_sync_queue_screen.dart';
import 'social_media_accounts_screen.dart';
import 'admin_social_media_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();

  Uint8List? _avatarBytes;
  bool _avatarLoading = true;
  int _avatarRequestVersion = 0;
  bool _currencyLoading = true;
  String? _selectedCurrency;
  List<Map<String, dynamic>> _currencyOptions = const [];
  String _syncSummary = 'Check data sync status';

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadCurrencyPreference();
    _loadSyncStatus();
  }

  Future<void> _loadAvatar() async {
    final requestVersion = ++_avatarRequestVersion;

    if (mounted) {
      setState(() => _avatarLoading = true);
    }

    try {
      final bytes = await _profileService.avatarImageBytes();

      if (!mounted || requestVersion != _avatarRequestVersion) return;

      setState(() {
        _avatarBytes = bytes.isEmpty ? null : Uint8List.fromList(bytes);
        _avatarLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || requestVersion != _avatarRequestVersion) return;

      // 404 means the account does not have a saved avatar yet. In that
      // case the normal initials fallback is the correct UI.
      if (e.statusCode == 404) {
        setState(() {
          _avatarBytes = null;
          _avatarLoading = false;
        });
        return;
      }

      setState(() => _avatarLoading = false);
    } catch (_) {
      if (!mounted || requestVersion != _avatarRequestVersion) return;
      setState(() => _avatarLoading = false);
    }
  }

  Future<void> _loadSyncStatus() async {
    final snapshot = await SyncStatusService().refresh();
    if (!mounted) return;
    String label;
    if (snapshot.conflicts > 0) {
      label =
          '${snapshot.conflicts} change${snapshot.conflicts == 1 ? '' : 's'} need review';
    } else if (!snapshot.online) {
      label = snapshot.totalPending > 0
          ? 'Offline · ${snapshot.totalPending} change${snapshot.totalPending == 1 ? '' : 's'} saved on this device'
          : 'Offline · saved data remains available';
    } else if (snapshot.totalPending > 0) {
      label =
          '${snapshot.totalPending} item${snapshot.totalPending == 1 ? '' : 's'} waiting to sync';
    } else if (snapshot.lastSyncedAt != null) {
      final diff = DateTime.now().difference(snapshot.lastSyncedAt!);
      if (diff.inMinutes < 1) {
        label = 'Synced just now';
      } else if (diff.inMinutes < 60) {
        label = 'Synced ${diff.inMinutes} min ago';
      } else {
        label = 'Synced ${diff.inHours} hr ago';
      }
    } else {
      label = 'Online · ready to sync';
    }
    setState(() => _syncSummary = label);
  }

  Future<void> _loadCurrencyPreference() async {
    try {
      final data = await _profileService.currencyPreference();
      BrandingService.applyCurrencyPreference(data);
      if (!mounted) return;
      setState(() {
        _selectedCurrency = (data['selected'] ?? '').toString().toUpperCase();
        _currencyOptions = _sanitizeCurrencyOptions(
          data['options'] as List? ?? const [],
        );
        _currencyLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _currencyLoading = false);
    }
  }

  List<Map<String, dynamic>> _sanitizeCurrencyOptions(List<dynamic>? rows) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final row in rows ?? const []) {
      if (row is! Map) continue;
      final code = (row['code'] ?? '').toString().trim().toUpperCase();
      if (code.isEmpty || !seen.add(code)) continue;
      result.add(Map<String, dynamic>.from(row)..['code'] = code);
    }
    return result;
  }

  Future<void> _openCurrencyPicker() async {
    if (_currencyLoading) return;
    if (_currencyOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No additional currencies are configured yet.'),
        ),
      );
      return;
    }

    final optionCodes = _currencyOptions
        .map((option) => (option['code'] ?? '').toString().toUpperCase())
        .toList(growable: false);
    String value = optionCodes.contains(_selectedCurrency)
        ? _selectedCurrency!
        : optionCodes.first;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferred Currency',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose how amounts are displayed in My Digital Diary. This does not change the original stored amounts or payment gateway settlement currency.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: value,
                        isExpanded: true,
                        menuMaxHeight: MediaQuery.sizeOf(context).height * 0.42,
                        decoration: InputDecoration(
                          labelText: 'Display currency',
                          prefixIcon: const Icon(Icons.currency_exchange),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        selectedItemBuilder: (context) => _currencyOptions.map((
                          option,
                        ) {
                          final code = (option['code'] ?? '')
                              .toString()
                              .toUpperCase();
                          final symbol = (option['symbol'] ?? code).toString();
                          final rate =
                              double.tryParse(
                                (option['rate'] ?? '1').toString(),
                              ) ??
                              1;
                          final suffix = rate == 1 ? ' · Base' : '';
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$code ($symbol)$suffix',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        items: _currencyOptions.map((option) {
                          final code = (option['code'] ?? '')
                              .toString()
                              .toUpperCase();
                          final symbol = (option['symbol'] ?? code).toString();
                          final rate =
                              double.tryParse(
                                (option['rate'] ?? '1').toString(),
                              ) ??
                              1;
                          final hint = rate == 1
                              ? 'Base currency'
                              : '1 $code = ${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)} base units';
                          return DropdownMenuItem(
                            value: code,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$code ($symbol)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    hint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (next) {
                          if (next != null) setSheetState(() => value = next);
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(sheetContext, value),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Use this currency'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (chosen == null || chosen == _selectedCurrency) return;
    try {
      final data = await _profileService.updateCurrencyPreference(chosen);
      BrandingService.applyCurrencyPreference(data);
      if (!mounted) return;
      setState(() {
        _selectedCurrency = (data['selected'] ?? chosen)
            .toString()
            .toUpperCase();
        _currencyOptions = _sanitizeCurrencyOptions(
          data['options'] as List? ?? _currencyOptions,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Currency changed to $_selectedCurrency.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));

    if (!mounted) return;

    // The Edit Profile screen can upload/replace the avatar. Reload the
    // authenticated image bytes whenever the user returns to this screen so
    // the Profile header updates immediately without restarting the app.
    await _loadAvatar();
  }

  Widget _avatar(BuildContext context, String? name) {
    final primary = Theme.of(context).colorScheme.primary;
    final initial = (name?.trim().isNotEmpty == true ? name!.trim()[0] : '?')
        .toUpperCase();

    return CircleAvatar(
      radius: 40,
      backgroundColor: primary.withValues(alpha: 0.10),
      backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
      child: _avatarBytes != null
          ? null
          : _avatarLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            )
          : Text(
              initial,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _loadAvatar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  _avatar(context, user?.name),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Profile'),
                subtitle: const Text('Name, email, avatar, and password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openEditProfile,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Subscription'),
                    subtitle: Text(user?.subscriptionStatus ?? '—'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('Family, Team & Organization'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OrganizationScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.currency_exchange_outlined),
                    title: const Text('Preferred Currency'),
                    subtitle: Text(
                      _currencyLoading
                          ? 'Loading currencies…'
                          : (_selectedCurrency?.isNotEmpty == true
                                ? 'Display amounts in $_selectedCurrency'
                                : 'Choose how amounts are displayed'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openCurrencyPicker,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_done_outlined),
                    title: const Text('Data Sync'),
                    subtitle: Text(_syncSummary),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OfflineSyncQueueScreen(),
                        ),
                      );
                      await _loadSyncStatus();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Appearance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppearanceScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune_outlined),
                    title: const Text('Personalisation & AI Privacy'),
                    subtitle: const Text(
                      'Choose priorities and what AI may use',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PersonalisationScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: const Text('Social Media Settings'),
                    subtitle: const Text(
                      'WhatsApp Status, Channel and social accounts',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SocialMediaAccountsScreen(),
                      ),
                    ),
                  ),
                  if (user != null &&
                      (user.role == 'admin' || user.role == 'super_admin')) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Admin Social Media'),
                      subtitle: const Text(
                        'Review users, accounts and scheduled communication',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminSocialMediaScreen(),
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_view_month_outlined),
                    title: const Text('My Month in Review'),
                    subtitle: const Text(
                      'See progress, wins and next-month focus',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MonthlyReviewScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.vpn_key_outlined),
                    title: const Text('API Keys'),
                    subtitle: const Text('For AI Planner generation'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.person_add_alt_outlined),
                    title: Text('Invite a Friend'),
                    trailing: Icon(Icons.chevron_right),
                    onTap: _inviteAFriend,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFE11D48)),
                title: const Text(
                  'Log Out',
                  style: TextStyle(color: Color(0xFFE11D48)),
                ),
                onTap: () => auth.logout(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _inviteAFriend() async {
  final base = ApiClient.baseUrl.replaceAll('/api', '');
  await SharePlus.instance.share(
    ShareParams(
      text:
          "I've been using My Digital Diary to track expenses, health, projects and more, all in one app. "
          'Give it a try: $base',
      subject: 'Try My Digital Diary',
    ),
  );
}
