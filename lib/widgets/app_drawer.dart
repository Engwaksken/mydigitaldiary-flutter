import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../screens/monthly_review_screen.dart';
import '../screens/goal_intelligence_screen.dart';
import '../screens/personalisation_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';
import '../config/module_configs.dart';
import '../models/field_config.dart';
import '../screens/reminders_screen.dart';
import '../screens/meetings_screen.dart';
import '../screens/dynamic_crud_screen.dart';
import '../screens/business_card_screen.dart';
import '../screens/signatures_screen.dart';
import '../screens/subscription_screen.dart';
import '../screens/organization_screen.dart';
import '../screens/ai_planner_screen.dart';
import '../screens/financial_planner_screen.dart';
import '../screens/finance_report_screen.dart';
import '../screens/daily_planner_screen.dart';
import '../screens/annual_plans_screen.dart';
import '../screens/help_screen.dart';
import '../screens/api_keys_screen.dart';
import '../screens/account_data_screen.dart';
import '../screens/privacy_data_screen.dart';
import '../screens/debts_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/people_connections_screen.dart';
import '../screens/daily_routine_screen.dart';

/// Every module the app has, grouped the same way as the web app's
/// sidebar — the mobile equivalent of that persistent left navigation.
/// Reachable from the Home tab's hamburger icon; Feedback/Subscription/
/// Organization/Profile also have their own dedicated homes (bottom nav
/// or the Profile screen) since those are common enough to deserve a
/// shortcut, but they stay listed here too for discoverability.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  String _safeFirstName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return '';
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 220,
            child: DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF00897B)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DrawerAvatar(
                  name: auth.user?.name,
                  avatarVersion: auth.avatarRevision,
                ),
                const SizedBox(height: 10),
                Text(
                  'Hi, ${_safeFirstName(auth.user?.name)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            ),
          ),
          _DrawerGroup(
            title: 'Finance',
            icon: Icons.savings_outlined,
            children: [
              _DrawerTileToScreen(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Financial Planner',
                builder: (_) => const FinancialPlannerScreen(),
              ),
              _DrawerTileToScreen(icon: Icons.trending_up, title: 'Income', builder: (_) => const FinanceReportScreen(endpoint: 'incomes', title: 'Income')),
              _DrawerTileToScreen(icon: Icons.account_balance_wallet_outlined, title: 'Budgets', builder: (_) => const FinanceReportScreen(endpoint: 'budgets', title: 'Budgets')),
              _DrawerTileToScreen(icon: Icons.receipt_long_outlined, title: 'Expenses', builder: (_) => const FinanceReportScreen(endpoint: 'expenses', title: 'Expenses')),
              _DrawerTileToScreen(icon: Icons.handshake_outlined, title: 'Debts', builder: (_) => const DebtsScreen()),
              _DrawerTileToScreen(icon: Icons.savings_outlined, title: 'Savings', builder: (_) => const SavingsScreen()),
              _DrawerTileToScreen(icon: Icons.add_card_outlined, title: 'Contributions', builder: (_) => const FinanceReportScreen(endpoint: 'savings-contributions', title: 'Savings Contributions')),
            ],
          ),
          _DrawerGroup(
            title: 'Health & Wellness',
            icon: Icons.favorite_border,
            children: [
              _drawerTile(context, moduleConfigByEndpoint('diet-logs')),
              _drawerTile(context, moduleConfigByEndpoint('exercise-logs')),
              _drawerTile(context, moduleConfigByEndpoint('sleep-logs')),
              _drawerTile(context, moduleConfigByEndpoint('health-checkups')),
              _drawerTile(context, moduleConfigByEndpoint('wellbeing')),
            ],
          ),
          _DrawerGroup(
            title: 'Work & Projects',
            icon: Icons.work_outline,
            children: [
              _drawerTile(context, moduleConfigByEndpoint('projects')),
              _drawerTile(context, moduleConfigByEndpoint('project-tasks')),
              _DrawerTileToScreen(icon: Icons.calendar_month_outlined, title: 'Meetings', builder: (_) => const MeetingsScreen()),
            ],
          ),
          _DrawerGroup(
            title: 'Personal Life',
            icon: Icons.groups_2_outlined,
            children: [
              _drawerTile(context, moduleConfigByEndpoint('education-plans')),
              _DrawerTileToScreen(icon: Icons.hub_outlined, title: 'Networks', builder: (_) => const PeopleConnectionsScreen.networks()),
              _DrawerTileToScreen(icon: Icons.favorite_border_rounded, title: 'Relationships', builder: (_) => const PeopleConnectionsScreen.relationships()),
              _drawerTile(context, moduleConfigByEndpoint('spiritual-practices')),
            ],
          ),
          _DrawerGroup(
            title: 'Productivity',
            icon: Icons.bolt_outlined,
            children: [
              _DrawerTileToScreen(
                icon: Icons.today_outlined,
                title: 'Daily Planner',
                builder: (_) => const DailyPlannerScreen(),
              ),
              _DrawerTileToScreen(icon: Icons.wb_sunny_outlined, title: 'Start Day', builder: (_) => const DailyRoutineScreen.start()),
              _DrawerTileToScreen(icon: Icons.nights_stay_outlined, title: 'End Day', builder: (_) => const DailyRoutineScreen.end()),
              _DrawerTileToScreen(
                icon: Icons.event_note_outlined,
                title: 'Annual Plans',
                builder: (_) => const AnnualPlansScreen(),
              ),
              _DrawerTileToScreen(icon: Icons.calendar_view_month_outlined, title: 'Month in Review', builder: (_) => const MonthlyReviewScreen()),
              _DrawerTileToScreen(icon: Icons.explore_outlined, title: 'Goals & Next Actions', builder: (_) => const GoalIntelligenceScreen()),
              _drawerTile(context, moduleConfigByEndpoint('personal-goals')),
              _DrawerTileToScreen(icon: Icons.notifications_outlined, title: 'Reminders', builder: (_) => const RemindersScreen()),
              _DrawerTileToScreen(icon: Icons.auto_awesome, title: 'AI Planner', builder: (_) => const AiPlannerScreen()),
              _drawerTile(context, moduleConfigByEndpoint('notes')),
            ],
          ),
          _DrawerGroup(
            title: 'Tools & Account',
            icon: Icons.build_outlined,
            children: [
              _DrawerTileToScreen(icon: Icons.draw_outlined, title: 'Signatures', builder: (_) => const SignaturesScreen()),
              _DrawerTileToScreen(icon: Icons.badge_outlined, title: 'Business Card', builder: (_) => const BusinessCardScreen()),
              _DrawerTileToScreen(icon: Icons.vpn_key_outlined, title: 'API Keys', builder: (_) => const ApiKeysScreen()),
              _DrawerTileToScreen(icon: Icons.tune_outlined, title: 'Personalisation & AI Privacy', builder: (_) => const PersonalisationScreen()),
              _DrawerTileToScreen(icon: Icons.cloud_sync_outlined, title: 'Backup, Trash & Usage', builder: (_) => const AccountDataScreen()),
              _DrawerTileToScreen(icon: Icons.privacy_tip_outlined, title: 'Privacy & Data', builder: (_) => const PrivacyDataScreen()),
              _DrawerTileToScreen(icon: Icons.workspace_premium_outlined, title: 'Subscription', builder: (_) => const SubscriptionScreen()),
              _DrawerTileToScreen(icon: Icons.groups_outlined, title: 'Family, Team & Organization', builder: (_) => const OrganizationScreen()),
              _drawerTile(context, moduleConfigByEndpoint('feedback')),
              _DrawerTileToScreen(icon: Icons.help_outline, title: 'Help & FAQ', builder: (_) => const HelpScreen()),
            ],
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE11D48)),
            title: const Text('Log Out', style: TextStyle(color: Color(0xFFE11D48))),
            onTap: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
    );
  }
}

class _DrawerAvatar extends StatefulWidget {
  final String? name;
  final int avatarVersion;

  const _DrawerAvatar({required this.name, required this.avatarVersion});

  @override
  State<_DrawerAvatar> createState() => _DrawerAvatarState();
}

class _DrawerAvatarState extends State<_DrawerAvatar> {
  final ProfileService _profileService = ProfileService();
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _DrawerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // AuthService increments avatarVersion after every successful upload.
    // The image itself always comes from the authenticated endpoint.
    if (oldWidget.avatarVersion != widget.avatarVersion) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final raw = await _profileService
          .avatarImageBytes(revision: widget.avatarVersion)
          .timeout(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _bytes = raw.isEmpty ? null : Uint8List.fromList(raw);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 404) _bytes = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = (widget.name?.trim().isNotEmpty == true
            ? widget.name!.trim()[0]
            : '?')
        .toUpperCase();

    return CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white24,
      backgroundImage: _bytes != null ? MemoryImage(_bytes!) : null,
      child: _bytes != null
          ? null
          : _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
    );
  }
}

Widget _drawerTile(BuildContext context, ModuleConfig config) {
  return ListTile(
    leading: Icon(config.icon, color: config.color),
    title: Text(config.title),
    onTap: () {
      Navigator.of(context).pop(); // close the drawer first
      // Deferred to the next frame — pushing a new route in the exact
      // same synchronous tick as closing the drawer can interfere with
      // the drawer's own close animation/transition, occasionally
      // causing the push to be silently dropped. Letting the pop
      // actually finish first avoids that.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DynamicCrudScreen(config: config)));
      });
    },
  );
}

class _DrawerTileToScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final WidgetBuilder builder;

  const _DrawerTileToScreen({required this.icon, required this.title, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(MaterialPageRoute(builder: builder));
        });
      },
    );
  }
}

class _DrawerGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DrawerGroup({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: children,
    );
  }
}
