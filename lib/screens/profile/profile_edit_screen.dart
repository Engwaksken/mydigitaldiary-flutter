import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/api_list_screen.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState
    extends State<ProfileEditScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController phoneController;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    final user = context.read<AuthProvider>().user!;

    nameController =
        TextEditingController(text: user.name);

    emailController =
        TextEditingController(text: user.email);

    phoneController =
        TextEditingController(text: user.phone ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (saving) return;

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final api = ApiProvider.read(context);
    final auth = context.read<AuthProvider>();

    FocusScope.of(context).unfocus();

    setState(() => saving = true);

    try {
      final response = await api.putMap(
        '/profile',
        {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
        },
      );

      if (!mounted) return;

      final raw =
          response['user'] ??
          response['data']?['user'] ??
          response['data'];

      if (raw is! Map) {
        throw Exception(
          'The server updated the profile but did not return the user record.',
        );
      }

      auth.setCurrentUser(
        Map<String, dynamic>.from(raw),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => saving = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              api.readableError(error),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthProvider>().user!;

    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
        ),
        body: Stack(
          children: [
            Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                      side: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Personal information',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Update your personal details. Role and branch access are managed by an administrator.',
                            style: TextStyle(
                              color:
                                  Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller:
                                nameController,
                            textCapitalization:
                                TextCapitalization
                                    .words,
                            textInputAction:
                                TextInputAction.next,
                            decoration:
                                const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(
                                Icons
                                    .person_outline,
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value
                                          .trim()
                                          .length <
                                      2) {
                                return 'Enter your full name.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          TextFormField(
                            controller:
                                emailController,
                            keyboardType:
                                TextInputType
                                    .emailAddress,
                            textInputAction:
                                TextInputAction.next,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Email address',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                              ),
                            ),
                            validator: (value) {
                              final email =
                                  value?.trim() ?? '';

                              if (email.isEmpty ||
                                  !email.contains('@')) {
                                return 'Enter a valid email address.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          TextFormField(
                            controller:
                                phoneController,
                            keyboardType:
                                TextInputType.phone,
                            textInputAction:
                                TextInputAction.done,
                            onFieldSubmitted: (_) =>
                                saveProfile(),
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Phone number',
                              prefixIcon: Icon(
                                Icons.phone_outlined,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Container(
                            padding:
                                const EdgeInsets.all(
                              14,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(
                                    alpha: .06,
                                  ),
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Text(
                                  'Account access',
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Role: ${user.role.replaceAll('_', ' ')}',
                                ),
                                if (user.propertyName !=
                                    null)
                                  Text(
                                    'Branch: ${user.propertyName}',
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: saving
                                  ? null
                                  : saveProfile,
                              icon: saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .save_outlined,
                                    ),
                              label: Text(
                                saving
                                    ? 'Saving…'
                                    : 'Save changes',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (saving)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x11000000),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
