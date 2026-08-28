import 'package:flutter/material.dart';
import '../../widgets/api_list_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiListScreen(
      title: 'My Tasks',
      endpoint: '/tasks',
      icon: Icons.task_alt,
      preferredFields: ['title', 'task', 'description'],
    );
  }
}
