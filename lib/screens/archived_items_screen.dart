import 'package:flutter/material.dart';
import '../models/field_config.dart';
import '../models/dynamic_item.dart';
import '../services/dynamic_crud_service.dart';
import '../services/api_client.dart';
import '../widgets/confirm_action_dialog.dart';

/// Shows only archived items for one module, with an unarchive action
/// per item — reached from that module's own list screen. No edit/add
/// here since an archived item's whole point is being out of the way;
/// unarchive it first to get back to the normal editable list.
class ArchivedItemsScreen extends StatefulWidget {
  final ModuleConfig config;

  const ArchivedItemsScreen({super.key, required this.config});

  @override
  State<ArchivedItemsScreen> createState() => _ArchivedItemsScreenState();
}

class _ArchivedItemsScreenState extends State<ArchivedItemsScreen> {
  late final _service = DynamicCrudService(widget.config.endpoint);
  List<DynamicItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.list(archived: true);
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _unarchive(DynamicItem item) async {
    try {
      await _service.unarchive(item.id);
      setState(() => _items.removeWhere((i) => i.id == item.id));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }


  Future<void> _delete(DynamicItem item) async {
    final title = _formatValue(item[widget.config.titleField]);
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete permanently?',
      message: title.isEmpty ? 'This archived item will be permanently deleted.' : 'Delete “$title” permanently? This action cannot be undone.',
      confirmText: 'Delete permanently',
    );
    if (!confirmed) return;

    try {
      await _service.delete(item.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((i) => i.id == item.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    return Scaffold(
      appBar: AppBar(title: Text('Archived — ${config.title}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Nothing archived here.', textAlign: TextAlign.center),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          leading: Icon(config.icon, color: Colors.grey),
                          title: Text(
                            _formatValue(item[config.titleField]).isEmpty ? '(untitled)' : _formatValue(item[config.titleField]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _unarchive(item),
                                child: const Text('Unarchive'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete permanently',
                                onPressed: () => _delete(item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
