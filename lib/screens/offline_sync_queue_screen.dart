import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/offline_mutation_queue.dart';

class OfflineSyncQueueScreen extends StatefulWidget {
  const OfflineSyncQueueScreen({super.key});

  @override
  State<OfflineSyncQueueScreen> createState() => _OfflineSyncQueueScreenState();
}

class _OfflineSyncQueueScreenState extends State<OfflineSyncQueueScreen> {
  List<OfflineMutation> _items = const [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await OfflineMutationQueue.instance.all();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final result = await OfflineMutationQueue.instance.syncAll();
    await _load();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${result['synced']} synced · ${result['remaining']} remaining${(result['conflicts'] ?? 0) > 0 ? ' · ${result['conflicts']} need review' : ''}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Sync'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: _syncing || _items.isEmpty ? null : _sync,
            icon: _syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_done_outlined, size: 48),
                    SizedBox(height: 12),
                    Text('Everything is synced.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('Offline changes to Planner, Notes, Tasks and Expenses will appear here until they reach the server.', textAlign: TextAlign.center),
                  ]),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final conflict = item.status == 'conflict';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: conflict ? Colors.red.withValues(alpha: .1) : Theme.of(context).colorScheme.primary.withValues(alpha: .1),
                            child: Icon(conflict ? Icons.sync_problem_outlined : Icons.cloud_upload_outlined, color: conflict ? Colors.red : Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${item.module} · ${item.method} · ${DateFormat('d MMM, h:mm a').format(item.createdAt)}'),
                            if (conflict && (item.error ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(item.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                          ]),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'retry') await OfflineMutationQueue.instance.retry(item.id);
                              if (value == 'force') await OfflineMutationQueue.instance.forceLocalVersion(item.id);
                              if (value == 'discard') await OfflineMutationQueue.instance.discard(item.id);
                              await _load();
                            },
                            itemBuilder: (_) => [
                              if (conflict) const PopupMenuItem(value: 'retry', child: Text('Retry')),
                              if (conflict) const PopupMenuItem(value: 'force', child: Text('Keep my version & sync')),
                              const PopupMenuItem(value: 'discard', child: Text('Use server version / discard local')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
