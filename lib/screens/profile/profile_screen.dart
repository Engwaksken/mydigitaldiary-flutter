import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/section_card.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> openEdit(
    BuildContext context,
  ) async {
    final changed =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            const ProfileEditScreen(),
      ),
    );

    if (!context.mounted || changed != true) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => openEdit(context),
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  child: Text(
                    user.name.isNotEmpty
                        ? user.name[0]
                            .toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                if (user.phone != null &&
                    user.phone!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.phone!,
                    style: TextStyle(
                      color:
                          Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  alignment:
                      WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        user.role
                            .replaceAll('_', ' '),
                      ),
                    ),
                    if (user.propertyName !=
                        null)
                      Chip(
                        label: Text(
                          user.propertyName!,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => openEdit(context),
            icon:
                const Icon(Icons.edit_outlined),
            label:
                const Text('Edit profile'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
