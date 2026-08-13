import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'dynamic_crud_screen.dart';
import '../config/module_configs.dart';
import '../services/reminder_alarm_service.dart';
import '../services/notification_service.dart';

/// Bottom navigation shell — Home / Notifications / Profile / Feedback,
/// per the requested bottom nav. IndexedStack keeps every tab's state
/// alive when switching between them (so Home doesn't re-fetch its
/// dashboard data every time you tap back to it), unlike rebuilding a
/// fresh screen on every tap.
///
/// Also owns the reminder-alarm polling — mobile equivalent of the web
/// dashboard's alarm popup. Runs here (not on a single tab) since it
/// needs to keep working no matter which tab is currently showing,
/// same as the web version keeps polling regardless of which part of
/// the page the user is looking at.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final _alarmService = ReminderAlarmService();
  Timer? _pollTimer;
  final Set<int> _dismissedIds = {};
  bool _dialogShowing = false;

  late final List<Widget> _tabs = [
    const DashboardScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
    DynamicCrudScreen(config: moduleConfigByEndpoint('feedback')),
  ];

  @override
  void initState() {
    super.initState();
    // 30s — frequent enough to feel prompt without hammering the
    // server; the web app's own polling interval is similar in spirit.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkDueReminders());
    _checkDueReminders();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDueReminders() async {
    if (_dialogShowing) return; // don't stack a second popup on top of one already showing
    try {
      final due = await _alarmService.dueNow();
      final notYetSeen = due.where((r) => !_dismissedIds.contains(r.id)).toList();
      if (notYetSeen.isEmpty || !mounted) return;

      final reminder = notYetSeen.first;
      await NotificationService.instance.showReminderAlarm(reminder.id, reminder.title, reminder.message);
      _showAlarmDialog(reminder);
    } catch (_) {
      // Silent — a failed poll (offline, server hiccup) just means
      // trying again on the next 30s tick, not something to surface
      // as an error to the user during otherwise-normal app use.
    }
  }

  void _showAlarmDialog(DueReminder reminder) {
    _dialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active, color: Color(0xFF00897B), size: 40),
        title: Text(reminder.title),
        content: reminder.message != null ? Text(reminder.message!) : null,
        actions: [
          TextButton(
            onPressed: () {
              _dismissedIds.add(reminder.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    ).then((_) => _dialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00897B),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.feedback_outlined), activeIcon: Icon(Icons.feedback), label: 'Feedback'),
        ],
      ),
    );
  }
}
