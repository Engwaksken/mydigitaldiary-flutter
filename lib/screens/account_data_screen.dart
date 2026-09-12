import 'package:flutter/material.dart';
import '../services/account_data_service.dart';
import '../widgets/confirm_action_dialog.dart';

class AccountDataScreen extends StatefulWidget {
  const AccountDataScreen({super.key});
  @override
  State<AccountDataScreen> createState() => _AccountDataScreenState();
}

class _AccountDataScreenState extends State<AccountDataScreen> {
  final _service = AccountDataService();
  Map<String, dynamic>? _usage;
  List<Map<String, dynamic>> _trash = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_service.usage(), _service.trash()]);
      if (!mounted) return;
      setState(() {
        _usage = results[0] as Map<String, dynamic>;
        _trash = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(int id) async {
    await _service.restore(id);
    await _load();
  }

  Future<void> _delete(int id) async {
    final ok = await showAppConfirmDialog(context,
        title: 'Delete permanently?',
        message: 'This item will no longer be recoverable.',
        confirmText: 'Delete permanently');
    if (ok) {
      await _service.deleteForever(id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_usage?['progress'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Your Data')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF17191D), Color(0xFF272D35)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 24,
                            offset: Offset(0, 12))
                      ]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.analytics_outlined,
                                color: Colors.white)),
                        const SizedBox(height: 18),
                        const Text('Usage progress',
                            style: TextStyle(
                                color: Color(0xFFB8C0CC), fontSize: 12)),
                        const SizedBox(height: 3),
                        Text('$pct%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 38,
                                letterSpacing: -1.5)),
                        const SizedBox(height: 12),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                                value: pct / 100,
                                minHeight: 7,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF69E0C2)))),
                        const SizedBox(height: 10),
                        Text(
                            '${_usage?['used_modules'] ?? 0} of ${_usage?['total_modules'] ?? 0} areas in use',
                            style: const TextStyle(
                                color: Color(0xFFB8C0CC), fontSize: 12)),
                      ]),
                ),
                const SizedBox(height: 14),
                const _InfoCard(
                    icon: Icons.cloud_download_outlined,
                    title: 'Private backup',
                    text:
                        'Download a full JSON backup from Profile → Backup & Usage on the web app. Your backup contains only your account data.'),
                const SizedBox(height: 22),
                Row(children: [
                  const Expanded(
                      child: Text('Recently deleted',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800))),
                  Text('${_trash.length} item(s)',
                      style: const TextStyle(color: Colors.grey, fontSize: 12))
                ]),
                const SizedBox(height: 10),
                if (_trash.isEmpty)
                  const _EmptyTrash()
                else
                  ..._trash.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF1F4F7),
                                borderRadius: BorderRadius.circular(13)),
                            child:
                                const Icon(Icons.restore_from_trash_outlined)),
                        title: Text(item['label']?.toString() ?? 'Untitled',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item['type']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12)),
                        trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              final id = (item['id'] as num).toInt();
                              if (v == 'restore') _restore(id);
                              if (v == 'delete') _delete(id);
                            },
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'restore', child: Text('Restore')),
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete permanently'))
                                ]),
                      ))),
              ])),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _InfoCard(
      {required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE7EBEF))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: const Color(0xFFEAF7F4),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: const Color(0xFF00897B))),
        const SizedBox(width: 13),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, height: 1.45, color: Color(0xFF667085)))
        ]))
      ]));
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE7EBEF))),
      child: const Column(children: [
        Icon(Icons.check_circle_outline, color: Color(0xFF36A58D), size: 30),
        SizedBox(height: 8),
        Text('Recycle bin is empty',
            style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 3),
        Text('Deleted supported records will appear here for 30 days.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF8A94A3)))
      ]));
}
