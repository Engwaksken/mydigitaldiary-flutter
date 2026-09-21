import 'package:flutter/material.dart';
import '../services/api_credential_service.dart';
import '../services/api_client.dart';

/// Mobile equivalent of the web app's /api-credentials page — under
/// Tools & Account, matching where this lives on web.
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  final _service = ApiCredentialService();
  ApiCredentialsOverview? _overview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await _service.overview();
      if (mounted) {
        setState(() {
          _overview = overview;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _activate(ApiCredential credential) async {
    try {
      await _service.activate(credential.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(ApiCredential credential) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this key?'),
        content: Text(
            '"${credential.label}" will no longer be usable for AI Plan generation.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.delete(credential.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _showAddDialog() async {
    final overview = _overview;
    if (overview == null || overview.providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('No AI providers are available to add a key for yet.')));
      return;
    }

    final labelController = TextEditingController();
    final keyController = TextEditingController();
    String selectedProvider = overview.providers.first.key;
    bool saving = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add API Key'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                      labelText: 'Label', hintText: 'e.g. My OpenAI Key'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedProvider,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: overview.providers
                      .map((p) =>
                          DropdownMenuItem(value: p.key, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(
                      () => selectedProvider = v ?? selectedProvider),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 8),
                  Text(formError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (labelController.text.trim().isEmpty ||
                          keyController.text.trim().isEmpty) {
                        setDialogState(() =>
                            formError = 'Label and API key are both required.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        formError = null;
                      });
                      try {
                        await _service.add(
                          label: labelController.text.trim(),
                          provider: selectedProvider,
                          apiKey: keyController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _load();
                      } on ApiException catch (e) {
                        setDialogState(() {
                          saving = false;
                          formError = e.message;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Keys')),
      floatingActionButton: FloatingActionButton(
          onPressed: _showAddDialog, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load: $_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSharedKeyStatus(),
                      const SizedBox(height: 20),
                      Text('Your Own Keys',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text(
                        "Your own key always takes priority when active, is unlimited, and uses your own account's cost — not the shared one below.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      if (_overview!.credentials.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No keys added yet — tap + to add one.',
                              style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._overview!.credentials.map((credential) => Card(
                              child: ListTile(
                                leading: Icon(
                                  credential.isActive
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: credential.isActive
                                      ? const Color(0xFF00897B)
                                      : Colors.grey,
                                ),
                                title: Text(credential.label),
                                subtitle: Text(credential.provider),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'activate') {
                                      _activate(credential);
                                    }
                                    if (value == 'delete') _delete(credential);
                                  },
                                  itemBuilder: (context) => [
                                    if (!credential.isActive)
                                      const PopupMenuItem(
                                          value: 'activate',
                                          child: Text('Set as Active')),
                                    const PopupMenuItem(
                                        value: 'delete', child: Text('Remove')),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSharedKeyStatus() {
    final overview = _overview!;

    if (!overview.hasSharedKeyConfigured) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10)),
        child: const Text(
          "No shared/free AI key has been configured by the admin. You'll need to add your own key above to use AI Plan generation.",
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    final remaining =
        (overview.sharedLimitPerMonth - overview.sharedUsedThisMonth)
            .clamp(0, overview.sharedLimitPerMonth);
    final exhausted = remaining <= 0 && !overview.hasOwnActiveKey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: exhausted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color:
                exhausted ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overview.hasOwnActiveKey
                ? 'Shared Key (not currently used — you have your own active)'
                : 'Shared Free Key',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${overview.sharedUsedThisMonth} of ${overview.sharedLimitPerMonth} free AI plans used this month.',
            style: const TextStyle(fontSize: 13),
          ),
          if (exhausted) ...[
            const SizedBox(height: 6),
            const Text(
              "You've used all your free plans for this month. Add your own key above to keep generating, or wait until next month.",
              style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
            ),
          ],
        ],
      ),
    );
  }
}
