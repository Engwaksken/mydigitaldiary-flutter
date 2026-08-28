import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/dashboard_stats.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/api_list_screen.dart';
import '../bookings/bookings_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../guests/guests_screen.dart';
import '../inventory/inventory_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pos/pos_screen.dart';
import '../profile/profile_screen.dart';
import '../rooms/rooms_screen.dart';
import '../tasks/tasks_screen.dart';

class DashboardScreen extends StatefulWidget {
  final bool embedded;

  const DashboardScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats stats = const DashboardStats();
  bool loading = true;
  bool started = false;

  Future<void> loadDashboard() async {
    try {
      final data =
          await ApiProvider.read(context).getMap('/dashboard');

      final raw = data['stats'] ?? data['data'] ?? data;

      if (raw is Map) {
        stats = DashboardStats.fromJson(
          Map<String, dynamic>.from(raw),
        );
      }
    } catch (_) {
      // Keep the dashboard available when statistics
      // cannot be loaded temporarily.
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!started) {
      started = true;
      loadDashboard();
    }
  }

  void openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  String roleName(String role) {
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
    final user = context.watch<AuthProvider>().user!;
    final width = MediaQuery.sizeOf(context).width;

    final money = NumberFormat.currency(
      symbol: 'UGX ',
      decimalDigits: 0,
    );

    const modules = <_DashboardModule>[
      _DashboardModule(
        label: 'Rooms',
        icon: Icons.bed_outlined,
        screen: RoomsScreen(),
      ),
      _DashboardModule(
        label: 'Bookings',
        icon: Icons.calendar_month_outlined,
        screen: BookingsScreen(),
      ),
      _DashboardModule(
        label: 'Guests',
        icon: Icons.people_alt_outlined,
        screen: GuestsScreen(),
      ),
      _DashboardModule(
        label: 'Tasks',
        icon: Icons.check_circle_outline_rounded,
        screen: TasksScreen(),
      ),
      _DashboardModule(
        label: 'Restaurant',
        icon: Icons.restaurant_rounded,
        screen: PosScreen(),
      ),
      _DashboardModule(
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        screen: InventoryScreen(),
      ),
      _DashboardModule(
        label: 'Chatbot',
        icon: Icons.chat_bubble_outline,
        screen: ChatbotScreen(),
      ),
      _DashboardModule(
        label: 'Alerts',
        icon: Icons.notifications_none_rounded,
        screen: NotificationsScreen(),
      ),
      _DashboardModule(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        screen: ProfileScreen(),
      ),
    ];

    final statsItems = <_DashboardStat>[
      _DashboardStat(
        label: 'Occupied',
        value: '${stats.occupiedRooms}',
        icon: Icons.bed_rounded,
      ),
      _DashboardStat(
        label: 'Available',
        value: '${stats.availableRooms}',
        icon: Icons.door_front_door_outlined,
      ),
      _DashboardStat(
        label: 'Arrivals',
        value: '${stats.arrivalsToday}',
        icon: Icons.login_rounded,
      ),
      _DashboardStat(
        label: 'Departures',
        value: '${stats.departuresToday}',
        icon: Icons.logout_rounded,
      ),
      _DashboardStat(
        label: 'Tasks',
        value: '${stats.openTasks}',
        icon: Icons.task_alt_rounded,
      ),
      _DashboardStat(
        label: 'Revenue',
        value: money.format(stats.revenueToday),
        icon: Icons.payments_outlined,
        compactValue: true,
      ),
    ];

    final content = RefreshIndicator(
      onRefresh: loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24,
        ),
        children: [
          /*
          |--------------------------------------------------------------------------
          | Compact Welcome Header
          |--------------------------------------------------------------------------
          */

          _WelcomeHeader(
            name: user.name,
            subtitle:
                user.propertyName ?? roleName(user.role),
          ),

          const SizedBox(height: 18),

          /*
          |--------------------------------------------------------------------------
          | Statistics
          |--------------------------------------------------------------------------
          */

          const _SectionTitle(
            title: 'Today at a glance',
            subtitle: 'Live hotel performance',
          ),

          const SizedBox(height: 10),

          GridView.builder(
            itemCount: statsItems.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: width >= 700 ? 6 : 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: width < 430 ? .92 : 1.05,
            ),
            itemBuilder: (context, index) {
              return _CompactStatTile(
                stat: statsItems[index],
              );
            },
          ),

          const SizedBox(height: 22),

          /*
          |--------------------------------------------------------------------------
          | Modules - App Launcher Style
          |--------------------------------------------------------------------------
          */

          const _SectionTitle(
            title: 'Hotel operations',
            subtitle: 'Tap an icon to open',
          ),

          const SizedBox(height: 14),

          GridView.builder(
            itemCount: modules.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: width >= 700 ? 6 : 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 16,
              childAspectRatio: .82,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];

              return _AppModuleIcon(
                module: module,
                onTap: () => openPage(module.screen),
              );
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel HMS'),
      ),
      body: content,
    );
  }
}

/*
|--------------------------------------------------------------------------
| Welcome Header
|--------------------------------------------------------------------------
*/

class _WelcomeHeader extends StatelessWidget {
  final String name;
  final String subtitle;

  const _WelcomeHeader({
    required this.name,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            name.isNotEmpty
                ? name.substring(0, 1).toUpperCase()
                : 'U',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${name.split(' ').first}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/*
|--------------------------------------------------------------------------
| Section Title
|--------------------------------------------------------------------------
*/

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/*
|--------------------------------------------------------------------------
| Compact Statistics
|--------------------------------------------------------------------------
*/

class _CompactStatTile extends StatelessWidget {
  final _DashboardStat stat;

  const _CompactStatTile({
    required this.stat,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 35,
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              stat.icon,
              color: primary,
              size: 20,
            ),
          ),

          const SizedBox(height: 7),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: stat.compactValue ? 15 : 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
            ),
          ),

          const SizedBox(height: 2),

          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| App Launcher Style Module
|--------------------------------------------------------------------------
*/

class _AppModuleIcon extends StatelessWidget {
  final _DashboardModule module;
  final VoidCallback onTap;

  const _AppModuleIcon({
    required this.module,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 2,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: primary.withValues(alpha: .06),
                  ),
                ),
                child: Icon(
                  module.icon,
                  size: 29,
                  color: primary,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                module.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| Models
|--------------------------------------------------------------------------
*/

class _DashboardModule {
  final String label;
  final IconData icon;
  final Widget screen;

  const _DashboardModule({
    required this.label,
    required this.icon,
    required this.screen,
  });
}

class _DashboardStat {
  final String label;
  final String value;
  final IconData icon;
  final bool compactValue;

  const _DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    this.compactValue = false,
  });
}
