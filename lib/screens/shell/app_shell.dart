import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../bookings/bookings_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../guests/guests_screen.dart';
import '../inventory/inventory_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pos/pos_screen.dart';
import '../profile/profile_screen.dart';
import '../rooms/rooms_screen.dart';
import '../tasks/tasks_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int currentIndex = 0;

  final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  late final List<_ShellDestination> bottomDestinations = [
    const _ShellDestination(
      label: 'Home',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      screen: DashboardScreen(
        embedded: true,
      ),
    ),
    const _ShellDestination(
      label: 'Rooms',
      icon: Icons.meeting_room_outlined,
      selectedIcon: Icons.meeting_room,
      screen: RoomsScreen(),
    ),
    const _ShellDestination(
      label: 'Bookings',
      icon: Icons.event_available_outlined,
      selectedIcon: Icons.event_available,
      screen: BookingsScreen(),
    ),
    const _ShellDestination(
      label: 'Tasks',
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt,
      screen: TasksScreen(),
    ),
    const _ShellDestination(
      label: 'Chatbot',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      screen: ChatbotScreen(),
    ),
  ];

  String get pageTitle {
    switch (currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Rooms';
      case 2:
        return 'Bookings';
      case 3:
        return 'My Tasks';
      case 4:
        return 'Hotel Chatbot';
      default:
        return 'Hotel HMS';
    }
  }

  void goToBottomIndex(int index) {
    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );

    setState(() {
      currentIndex = index;
    });
  }

  void openModule(
    Widget screen, {
    String? title,
  }) {
    Navigator.of(context).pop();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  Future<void> logout() async {
    Navigator.of(context).pop();

    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(pageTitle),
        leading: IconButton(
          tooltip: 'Menu',
          onPressed: () =>
              scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const NotificationsScreen(),
                ),
              );
            },
            icon:
                const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
            icon:
                const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _HotelDrawer(
        userName: user?.name ?? 'Hotel User',
        email: user?.email ?? '',
        role: user?.role ?? 'staff',
        propertyName: user?.propertyName,
        onDashboard: () {
          Navigator.of(context).pop();
          setState(() => currentIndex = 0);
        },
        onRooms: () {
          Navigator.of(context).pop();
          setState(() => currentIndex = 1);
        },
        onBookings: () {
          Navigator.of(context).pop();
          setState(() => currentIndex = 2);
        },
        onTasks: () {
          Navigator.of(context).pop();
          setState(() => currentIndex = 3);
        },
        onChatbot: () {
          Navigator.of(context).pop();
          setState(() => currentIndex = 4);
        },
        onGuests: () =>
            openModule(const GuestsScreen()),
        onPos: () => openModule(const PosScreen()),
        onInventory: () =>
            openModule(const InventoryScreen()),
        onNotifications: () =>
            openModule(const NotificationsScreen()),
        onProfile: () =>
            openModule(const ProfileScreen()),
        onLogout: logout,
      ),
      body: IndexedStack(
        index: currentIndex,
        children: bottomDestinations
            .map((destination) => destination.screen)
            .toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: bottomDestinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon:
                    Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HotelDrawer extends StatelessWidget {
  final String userName;
  final String email;
  final String role;
  final String? propertyName;

  final VoidCallback onDashboard;
  final VoidCallback onRooms;
  final VoidCallback onBookings;
  final VoidCallback onGuests;
  final VoidCallback onTasks;
  final VoidCallback onChatbot;
  final VoidCallback onPos;
  final VoidCallback onInventory;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const _HotelDrawer({
    required this.userName,
    required this.email,
    required this.role,
    required this.propertyName,
    required this.onDashboard,
    required this.onRooms,
    required this.onBookings,
    required this.onGuests,
    required this.onTasks,
    required this.onChatbot,
    required this.onPos,
    required this.onInventory,
    required this.onNotifications,
    required this.onProfile,
    required this.onLogout,
  });

  String get roleLabel {
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                20,
                24,
                20,
                20,
              ),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: .08),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: primary,
                    child: Text(
                      userName.isNotEmpty
                          ? userName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text(roleLabel),
                        visualDensity:
                            VisualDensity.compact,
                      ),
                      if (propertyName != null &&
                          propertyName!
                              .trim()
                              .isNotEmpty)
                        Chip(
                          label: Text(propertyName!),
                          visualDensity:
                              VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 8,
                ),
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    onTap: onDashboard,
                  ),
                  _DrawerItem(
                    icon:
                        Icons.meeting_room_outlined,
                    label: 'Rooms',
                    onTap: onRooms,
                  ),
                  _DrawerItem(
                    icon:
                        Icons.event_available_outlined,
                    label: 'Bookings',
                    onTap: onBookings,
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Guests',
                    onTap: onGuests,
                  ),
                  _DrawerItem(
                    icon: Icons.task_alt_outlined,
                    label: 'My Tasks',
                    onTap: onTasks,
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chatbot',
                    onTap: onChatbot,
                  ),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: Divider(),
                  ),
                  _DrawerItem(
                    icon: Icons.restaurant_outlined,
                    label: 'Restaurant & Bar',
                    onTap: onPos,
                  ),
                  _DrawerItem(
                    icon:
                        Icons.inventory_2_outlined,
                    label: 'Inventory',
                    onTap: onInventory,
                  ),
                  _DrawerItem(
                    icon:
                        Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: onNotifications,
                  ),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: Divider(),
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    onTap: onProfile,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text(
                'Sign out',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _ShellDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });
}
