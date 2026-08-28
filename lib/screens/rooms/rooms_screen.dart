import 'package:flutter/material.dart';
import '../../widgets/api_list_screen.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiListScreen(
      title: 'Rooms',
      endpoint: '/rooms',
      icon: Icons.meeting_room_outlined,
      preferredFields: ['room_number', 'name', 'code'],
    );
  }
}
