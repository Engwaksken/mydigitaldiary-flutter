import 'package:flutter/material.dart';
import '../../widgets/api_list_screen.dart';

class GuestsScreen extends StatelessWidget {
  const GuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiListScreen(
      title: 'Guests',
      endpoint: '/guests',
      icon: Icons.people_outline,
      preferredFields: ['full_name', 'name', 'email'],
    );
  }
}
