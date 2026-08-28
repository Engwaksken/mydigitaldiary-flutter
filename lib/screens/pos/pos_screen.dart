import 'package:flutter/material.dart';
import '../../widgets/api_list_screen.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiListScreen(
      title: 'Restaurant & Bar',
      endpoint: '/pos/orders',
      icon: Icons.restaurant_outlined,
      preferredFields: ['order_number', 'reference', 'guest_name'],
    );
  }
}
