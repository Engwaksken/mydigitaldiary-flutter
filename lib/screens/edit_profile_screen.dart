import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/api_client.dart';

/// Name/email, avatar, and password — the three separate update
/// operations ProfileController exposes on the web side, combined
/// into one screen here for a shorter mobile navigation path rather
/// than three separate ones.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _service = ProfileService();
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _uploadingAvatar = false;
  bool _loadingAvatar = false;
  Uint8List? _avatarBytes;
  String? _profileError;
  String? _passwordError;
  String? _passwordSuccess;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().user;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    _loadAvatar();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    if (!mounted) return;
    setState(() => _loadingAvatar = true);
    try {
      final revision = context.read<AuthService>().avatarRevision;
      final bytes = await _service.avatarImageBytes(revision: revision);
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes.isEmpty ? null : Uint8List.fromList(bytes);
        _loadingAvatar = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // 404 simply means the user has no saved profile picture yet.
      setState(() {
        _avatarBytes = null;
        _loadingAvatar = false;
      });
      if (e.statusCode != 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load profile picture: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });
    try {
      final saved = await _service.updateProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim());
      if (!mounted) return;
      context
          .read<AuthService>()
          .updateProfileFields(name: saved['name'], email: saved['email']);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } on ApiException catch (e) {
      setState(() => _profileError = e.message);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _savingPassword = true;
      _passwordError = null;
      _passwordSuccess = null;
    });
    try {
      await _service.updatePassword(
        currentPassword: _currentPasswordController.text,
        password: _newPasswordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) setState(() => _passwordSuccess = 'Password updated.');
    } on ApiException catch (e) {
      setState(() => _passwordError = e.message);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  String _avatarContentType(XFile picked) {
    final name = picked.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked == null) return;

    if (!mounted) return;
    setState(() => _uploadingAvatar = true);

    try {
      final bytes = await File(picked.path).readAsBytes();
      if (bytes.isEmpty) {
        throw ApiException(422,
            'The selected profile picture is empty. Please choose another image.');
      }

      // Keep uploads comfortably below the server limit even if a gallery app
      // returns an unexpectedly large file after resizing/compression.
      if (bytes.length > 5 * 1024 * 1024) {
        throw ApiException(422,
            'Profile picture is still too large. Please choose a smaller image.');
      }

      final contentType = _avatarContentType(picked);
      final safeFileName = picked.name.trim().isEmpty
          ? (contentType == 'image/png'
              ? 'avatar.png'
              : contentType == 'image/webp'
                  ? 'avatar.webp'
                  : 'avatar.jpg')
          : picked.name;

      final avatarUrl = await _service.updateAvatar(
        fileBytes: bytes,
        fileName: safeFileName,
        contentType: contentType,
      );

      if (!mounted) return;
      final auth = context.read<AuthService>();
      auth.markAvatarUpdated(avatarUrl: avatarUrl);

      // The upload request has already succeeded, so use the exact selected
      // bytes immediately. Do not replace them with a second fetch in the same
      // tick: shared-hosting/proxy caches can briefly serve the previous file.
      setState(() => _avatarBytes = Uint8List.fromList(bytes));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not upload the profile picture. Check your connection and try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload profile picture: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0x1A00897B),
                  backgroundImage:
                      _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                  child: _loadingAvatar
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _avatarBytes == null
                          ? Text(
                              (user?.name.isNotEmpty == true
                                      ? user!.name[0]
                                      : '?')
                                  .toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00897B)),
                            )
                          : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF00897B),
                      child: _uploadingAvatar
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _profileFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Details', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                if (_profileError != null) ...[
                  const SizedBox(height: 8),
                  Text(_profileError!,
                      style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _savingProfile ? null : _saveProfile,
                  child: _savingProfile
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Details'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Form(
            key: _passwordFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Change Password',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Current Password'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'At least 8 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm New Password'),
                  validator: (v) => (v != _newPasswordController.text)
                      ? 'Passwords do not match'
                      : null,
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 8),
                  Text(_passwordError!,
                      style: const TextStyle(color: Colors.red)),
                ],
                if (_passwordSuccess != null) ...[
                  const SizedBox(height: 8),
                  Text(_passwordSuccess!,
                      style: const TextStyle(color: Colors.green)),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _savingPassword ? null : _changePassword,
                  child: _savingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Update Password'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
