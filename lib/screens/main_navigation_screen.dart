import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'signatures_screen.dart';
import 'profile_screen.dart';
import 'support_chat_screen.dart';
import 'business_card_screen.dart';
import '../services/reminder_alarm_service.dart';
import '../services/notification_service.dart';

/// Bottom navigation shell — Home / Signature / My Card / Profile / Chat,
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
  final Set<String> _dismissedOccurrences = {};
  String? _visibleReminderOccurrence;

  late final List<Widget> _tabs = [
    const DashboardScreen(),
    const SignaturesScreen(),
    const BusinessCardScreen(),
    const ProfileScreen(),
    const SupportChatScreen(),
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
    if (_visibleReminderOccurrence != null) return; // never stack reminder banners
    try {
      final due = await _alarmService.dueNow();
      final notYetSeen = due.where((r) => !_dismissedOccurrences.contains(r.occurrenceKey)).toList();
      if (notYetSeen.isEmpty || !mounted) return;

      final reminder = notYetSeen.first;
      await NotificationService.instance.showReminderAlarm(reminder.id, reminder.title, reminder.message);
      _showAlarmBanner(reminder);
    } catch (_) {
      // Silent — a failed poll (offline, server hiccup) just means
      // trying again on the next 30s tick, not something to surface
      // as an error to the user during otherwise-normal app use.
    }
  }

  void _showAlarmBanner(DueReminder reminder) {
    if (!mounted) return;
    _visibleReminderOccurrence = reminder.occurrenceKey;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 12),
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 84),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if ((reminder.message ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(reminder.message!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: const Color(0xFF99F6E4),
              onPressed: () {
                _dismissedOccurrences.add(reminder.occurrenceKey);
              },
            ),
          ),
        )
        .closed
        .whenComplete(() {
          if (!mounted) return;
          if (_visibleReminderOccurrence == reminder.occurrenceKey) {
            setState(() => _visibleReminderOccurrence = null);
          }
        });
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
        selectedFontSize: 10,
        unselectedFontSize: 10,
        iconSize: 22,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.draw_outlined), activeIcon: Icon(Icons.draw), label: 'Signature'),
          BottomNavigationBarItem(icon: Icon(Icons.badge_outlined), activeIcon: Icon(Icons.badge), label: 'My Card'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent_outlined), activeIcon: Icon(Icons.support_agent), label: 'Chat'),
        ],
      ),
    );
  }
}
