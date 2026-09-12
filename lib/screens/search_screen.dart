import 'dart:async';
import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../services/api_client.dart';
import '../config/module_configs.dart';
import 'dynamic_crud_screen.dart';
import 'expenses_screen.dart';
import 'reminders_screen.dart';
import 'annual_plans_screen.dart';

/// Searches across the highest-value, most commonly-used modules
/// (see SearchController on the Laravel side for the full list) —
/// not literally every one of the app's 20+ tables. Tapping a result
/// opens that module's list screen rather than deep-linking straight
/// to the matched item's own edit form, which would need changes to
/// how DynamicCrudScreen initializes across every module; this at
/// least narrows down exactly where the match lives.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = SearchService();
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _service.search(query.trim());
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            // Primary color for the typed text — a white/neutral search
            // box rather than embedding the field directly in the
            // colored app bar, since a light user-chosen primary color
            // (e.g. the sticky-notes Yellow) would make white text on
            // that background hard to read.
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary, fontSize: 15),
            cursorColor: Theme.of(context).colorScheme.primary,
            decoration: const InputDecoration(
              hintText: 'Search expenses, projects, meetings...',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _controller.text.trim().length < 2
                        ? 'Type at least 2 characters to search.'
                        : 'No matches found.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];

                    // expenses/reminders use bespoke screens, not
                    // DynamicCrudScreen — they're not registered in
                    // moduleConfigs at all, so moduleConfigByEndpoint()
                    // would throw for either one.
                    if (result.module == 'expenses') {
                      return ListTile(
                        leading: const Icon(Icons.receipt_long,
                            color: Color(0xFFE11D48)),
                        title: Text(result.title),
                        subtitle: result.subtitle != null
                            ? Text(result.subtitle!)
                            : const Text('Expenses'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ExpensesScreen())),
                      );
                    }
                    if (result.module == 'reminders') {
                      return ListTile(
                        leading: const Icon(Icons.notifications_active,
                            color: Color(0xFF00897B)),
                        title: Text(result.title),
                        subtitle: result.subtitle != null
                            ? Text(result.subtitle!)
                            : const Text('Reminders'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RemindersScreen())),
                      );
                    }
                    // Legacy plan search records now belong to Annual Plans.
                    if (result.module == 'plans' ||
                        result.module == 'annual_plans') {
                      return ListTile(
                        leading: const Icon(Icons.today_outlined,
                            color: Color(0xFF00897B)),
                        title: Text(result.title),
                        subtitle: const Text('Annual Plans'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AnnualPlansScreen())),
                      );
                    }

                    final config = moduleConfigByEndpoint(result.module);
                    return ListTile(
                      leading: Icon(config.icon, color: config.color),
                      title: Text(result.title),
                      subtitle: result.subtitle != null
                          ? Text(result.subtitle!)
                          : Text(config.title),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => DynamicCrudScreen(config: config)),
                      ),
                    );
                  },
                ),
    );
  }
}
