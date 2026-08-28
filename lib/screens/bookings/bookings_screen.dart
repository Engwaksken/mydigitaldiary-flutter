import 'package:flutter/material.dart';
import '../../widgets/api_list_screen.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiListScreen(
      title: 'Bookings',
      endpoint: '/bookings',
      icon: Icons.event_available_outlined,
      preferredFields: ['reference', 'booking_reference', 'guest_name', 'name'],
    );
  }
}
