import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'api_keys_screen.dart';
import 'appearance_screen.dart';
import 'edit_profile_screen.dart';
import 'organization_screen.dart';
import 'subscription_screen.dart';

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
  int _seenAvatarRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvatar());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = context.watch<AuthService>().avatarRevision;
    if (_seenAvatarRevision != revision) {
      _seenAvatarRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAvatar();
      });
    }
  }

  Future<void> _loadAvatar() async {
    final requestVersion = ++_avatarRequestVersion;

    if (mounted) {
      setState(() => _avatarLoading = true);
    }

    try {
      final revision = context.read<AuthService>().avatarRevision;
      final bytes = await _profileService.avatarImageBytes(revision: revision);

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

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (!mounted) return;

    // The Edit Profile screen can upload/replace the avatar. Reload the
    // authenticated image bytes whenever the user returns to this screen so
    // the Profile header updates immediately without restarting the app.
    await _loadAvatar();
  }

  Widget _avatar(BuildContext context, String? name) {
    final primary = Theme.of(context).colorScheme.primary;
    final initial = (name?.trim().isNotEmpty == true ? name!.trim()[0] : '?').toUpperCase();

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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
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
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('Family, Team & Organization'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrganizationScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Appearance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AppearanceScreen()),
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
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_outlined),
                    title: const Text('Invite a Friend'),
                    trailing: const Icon(Icons.chevron_right),
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
      text: "I've been using My Digital Diary to track expenses, health, projects and more, all in one app. "
          'Give it a try: $base',
      subject: 'Try My Digital Diary',
    ),
  );
}
