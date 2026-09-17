import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/dynamic_item.dart';
import '../models/field_config.dart';
import '../services/dynamic_crud_service.dart';
import '../services/api_client.dart';
import '../services/branding_service.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_text_field.dart';
import '../widgets/confirm_action_dialog.dart';
import 'archived_items_screen.dart';
import 'budgets_screen.dart';
import 'spiritual_growth_screen.dart';

/// One screen that works for any module described by a ModuleConfig —
/// see lib/config/module_configs.dart for the full list this drives.
/// Reminders/Meetings/Expenses keep their own bespoke screens (they
/// existed before this generic engine and have module-specific touches
/// like Expenses' running total); every module added afterward goes
/// through here instead of a new hand-written screen file.
class DynamicCrudScreen extends StatefulWidget {
  final ModuleConfig config;

  const DynamicCrudScreen({super.key, required this.config});

  @override
  State<DynamicCrudScreen> createState() => _DynamicCrudScreenState();
}

class _DynamicCrudScreenState extends State<DynamicCrudScreen> {
  late final DynamicCrudService _service = DynamicCrudService(
    widget.config.endpoint,
  );
  List<DynamicItem> _items = [];
  bool _loading = true;
  bool _redirectingToDedicatedScreen = false;
  String _educationStatusFilter = 'all';

  bool get _usesDedicatedScreen =>
      widget.config.endpoint == 'budgets' ||
      widget.config.endpoint == 'spiritual-practices';

  @override
  void initState() {
    super.initState();

    if (_usesDedicatedScreen) {
      _redirectingToDedicatedScreen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToDedicatedScreen();
      });
      return;
    }

    _load();
  }

  Future<void> _redirectToDedicatedScreen() async {
    if (!mounted) return;

    final Widget screen = switch (widget.config.endpoint) {
      'budgets' => const BudgetsScreen(),
      'spiritual-practices' => const SpiritualGrowthScreen(),
      _ => throw StateError(
        'No dedicated screen registered for ${widget.config.endpoint}.',
      ),
    };

    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _load() async {
    if (_usesDedicatedScreen) {
      if (!_redirectingToDedicatedScreen && mounted) {
        _redirectingToDedicatedScreen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _redirectToDedicatedScreen();
        });
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final items = await _service.list();
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Offline. No saved copy of this list is available yet.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(DynamicItem item) async {
    try {
      await _service.delete(
        item.id,
        baseUpdatedAt: item['updated_at']?.toString(),
      );
      if (!mounted) return;
      setState(() => _items.removeWhere((i) => i.id == item.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.config.title} item deleted.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<bool> _confirmDelete(DynamicItem item) {
    final title = _formatValue(item[widget.config.titleField]);
    return showAppConfirmDialog(
      context,
      title: 'Delete ${widget.config.title} item?',
      message: title.isEmpty
          ? 'This item will be permanently deleted.'
          : 'Delete “$title”? This action cannot be undone.',
      confirmText: 'Delete',
    );
  }

  Future<void> _archive(DynamicItem item) async {
    try {
      await _service.archive(item.id);
      setState(() => _items.removeWhere((i) => i.id == item.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archived. Find it later under Archived.'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  bool _downloadingPdf = false;
  final Set<int> _selectedIds = {};
  bool _bulkDeleting = false;

  Future<void> _downloadPdfReport() async {
    setState(() => _downloadingPdf = true);
    try {
      final bytes = await _service.downloadPdfBytes();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${widget.config.endpoint}-report.pdf';
      await File(path).writeAsBytes(bytes);

      if (!mounted) return;
      // Same share_plus API-version uncertainty flagged elsewhere in
      // this app — if this doesn't compile, use
      // Share.shareXFiles([XFile(path)]) instead.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: '${widget.config.title} Report',
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  void _openForm({DynamicItem? existing}) {
    if (_usesDedicatedScreen) {
      _redirectToDedicatedScreen();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _DynamicForm(
              config: widget.config,
              existing: existing,
              onSaved: () {
                Navigator.of(context).pop();
                _load();
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return '';
    final asString = value.toString();
    final parsed = DateTime.tryParse(asString);
    if (parsed != null) {
      // Show just the date for a bare date string, date+time otherwise —
      // a plain 'YYYY-MM-DD' parses to midnight, so that's the signal.
      // toLocal() only applies to the datetime case — a calendar date
      // like "2026-08-08" represents a day, not a UTC instant, and
      // converting it could incorrectly shift it to the previous day
      // for negative-offset timezones.
      final looksDateOnly = asString.length <= 10;
      return looksDateOnly
          ? DateFormat('yMMMd').format(parsed)
          : DateFormat('yMMMd, h:mm a').format(parsed.toLocal());
    }

    // Enum-style values (e.g. 'in_progress', 'scripture_reading') come
    // back from the API as the raw stored slug — humanize for display
    // rather than showing the underscore verbatim.
    if (RegExp(r'^[a-z]+(_[a-z]+)*$').hasMatch(asString)) {
      return asString
          .split('_')
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');
    }

    return asString;
  }

  /// Looks for a select field literally named 'status' with a
  /// 'completed' option — when a module has one (Projects, Tasks,
  /// Plans, Education Plans, etc.), a completion-percentage banner is
  /// shown above the list. Modules without this shape (Expenses,
  /// Income, and most others) simply don't get the banner, since
  /// "percent complete" isn't a meaningful concept for them.
  FieldConfig? _statusField() {
    for (final field in widget.config.fields) {
      if (field.name == 'status' && field.type == FieldType.select) {
        final hasCompletedOption =
            field.options?.any((o) => o.value == 'completed') ?? false;
        if (hasCompletedOption) return field;
      }
    }
    return null;
  }

  bool get _isEducation => widget.config.endpoint == 'education-plans';

  bool get _isHealth => widget.config.endpoint == 'health-checkups';

  bool get _isProjects => widget.config.endpoint == 'projects';

  List<DynamicItem> get _visibleItems {
    final items = _educationStatusFilter == 'all'
        ? List<DynamicItem>.from(_items)
        : _items
              .where((item) => item['status'] == _educationStatusFilter)
              .toList();

    if (_isEducation) {
      items.sort((a, b) {
        final aDate = DateTime.tryParse(
          a['target_completion_date']?.toString() ?? '',
        );
        final bDate = DateTime.tryParse(
          b['target_completion_date']?.toString() ?? '',
        );
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
    }

    return items;
  }

  Color _educationStatusColor(String? status) => switch (status) {
    'completed' => AppColors.success,
    'in_progress' => AppColors.forest,
    'on_hold' => AppColors.warning,
    _ => AppColors.textSecondary,
  };

  String? _educationDueLabel(DynamicItem item) {
    if (!_isEducation || item['status'] == 'completed') return null;
    final date = DateTime.tryParse(
      item['target_completion_date']?.toString() ?? '',
    );
    if (date == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    final due = DateUtils.dateOnly(date);
    final days = due.difference(today).inDays;
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days <= 14) return 'Due in $days days';
    return null;
  }

  String _dayLabel(int days) {
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  String? _healthDueLabel(DynamicItem item) {
    if (!_isHealth) return null;
    final date = DateTime.tryParse(
      item['next_due_date']?.toString() ??
          item['checkup_date']?.toString() ??
          '',
    );
    if (date == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    final due = DateUtils.dateOnly(date);
    return _dayLabel(due.difference(today).inDays);
  }

  String? _projectDueLabel(DynamicItem item) {
    if (!_isProjects || item['status'] == 'completed') return null;
    final date = DateTime.tryParse(item['deadline']?.toString() ?? '');
    if (date == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    final due = DateUtils.dateOnly(date);
    return _dayLabel(due.difference(today).inDays);
  }

  Widget _buildEducationFilters() {
    const filters = [
      ('all', 'All'),
      ('in_progress', 'In progress'),
      ('planned', 'Planned'),
      ('on_hold', 'On hold'),
      ('completed', 'Completed'),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          return ChoiceChip(
            label: Text(filter.$2),
            selected: _educationStatusFilter == filter.$1,
            onSelected: (_) =>
                setState(() => _educationStatusFilter = filter.$1),
          );
        },
      ),
    );
  }

  Widget _buildProgressBanner() {
    final total = _items.length;
    final completed = _items
        .where((item) => item['status'] == 'completed')
        .length;
    final percent = total > 0 ? (completed / total * 100) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: widget.config.color.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percent.toStringAsFixed(0)}% Complete',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.config.color,
                ),
              ),
              Text(
                '$completed of $total',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              minHeight: 6,
              backgroundColor: widget.config.color.withValues(alpha: 0.12),
              color: widget.config.color,
            ),
          ),
        ],
      ),
    );
  }

  /// For modules without a status field (Expenses, Income, and most
  /// others) — a completion percentage doesn't mean anything there,
  /// but a simple count still gives some sense of how much is
  /// tracked, matching the spirit of the request without forcing a
  /// meaningless percentage onto data that has no "done" state.
  Widget _buildItemCountBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: widget.config.color.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(widget.config.icon, size: 16, color: widget.config.color),
          const SizedBox(width: 8),
          Text(
            '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: widget.config.color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final visibleItems = _visibleItems;

    if (_usesDedicatedScreen) {
      return Scaffold(
        appBar: AppBar(title: Text(config.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIds.isEmpty
              ? config.title
              : '${_selectedIds.length} selected',
        ),
        leading: _selectedIds.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIds.clear()),
              ),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: _bulkDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Delete selected',
              onPressed: _bulkDeleting
                  ? null
                  : () async {
                      final ok = await showAppConfirmDialog(
                        context,
                        title: 'Delete selected items?',
                        message:
                            'You are about to permanently delete ${_selectedIds.length} selected item${_selectedIds.length == 1 ? '' : 's'}.',
                        confirmText: 'Delete selected',
                      );
                      if (ok) {
                        setState(() => _bulkDeleting = true);
                        try {
                          await _service.bulkDelete(_selectedIds.toList());
                          _selectedIds.clear();
                          await _load();
                        } finally {
                          if (mounted) setState(() => _bulkDeleting = false);
                        }
                      }
                    },
            ),
          IconButton(
            icon: _downloadingPdf
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download PDF Report',
            onPressed: _downloadingPdf ? null : _downloadPdfReport,
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archived',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArchivedItemsScreen(config: config),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: config.color,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: AppLayout.bounded(
          child: Column(
            children: [
              if (_statusField() != null)
                _buildProgressBanner()
              else
                _buildItemCountBanner(),
              if (_isEducation) _buildEducationFilters(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visibleItems.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    _isEducation
                                        ? Icons.school_outlined
                                        : config.icon,
                                    size: 44,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isEducation &&
                                            _educationStatusFilter != 'all'
                                        ? 'No ${_formatValue(_educationStatusFilter).toLowerCase()} plans.'
                                        : 'Nothing here yet. Tap + to add one.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: AppLayout.pagePadding(context),
                          itemCount: visibleItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            final subtitleParts = <String>[];
                            if (config.subtitleField != null &&
                                item[config.subtitleField!] != null) {
                              subtitleParts.add(
                                _formatValue(item[config.subtitleField!]),
                              );
                            }
                            if (config.dateField != null &&
                                item[config.dateField!] != null) {
                              subtitleParts.add(
                                _formatValue(item[config.dateField!]),
                              );
                            }
                            final dueLabel =
                                _educationDueLabel(item) ??
                                _healthDueLabel(item) ??
                                _projectDueLabel(item);
                            if (dueLabel != null) subtitleParts.add(dueLabel);

                            return Dismissible(
                              key: ValueKey(item.id),
                              direction: DismissDirection.horizontal,
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  await _archive(item);
                                  return false;
                                }
                                if (await _confirmDelete(item)) {
                                  await _delete(item);
                                }
                                return false;
                              },
                              background: Container(
                                color: AppColors.textSecondary,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Icon(
                                  Icons.archive_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              secondaryBackground: Container(
                                color: AppColors.danger,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: _selectedIds.isNotEmpty
                                      ? Checkbox(
                                          value: _selectedIds.contains(item.id),
                                          onChanged: (_) => setState(() {
                                            if (_selectedIds.contains(
                                              item.id,
                                            )) {
                                              _selectedIds.remove(item.id);
                                            } else {
                                              _selectedIds.add(item.id);
                                            }
                                          }),
                                        )
                                      : CircleAvatar(
                                          backgroundColor: config.color
                                              .withValues(alpha: 0.12),
                                          child: Icon(
                                            config.icon,
                                            color: config.color,
                                          ),
                                        ),
                                  title: Text(
                                    _formatValue(
                                          item[config.titleField],
                                        ).isEmpty
                                        ? '(untitled)'
                                        : _formatValue(item[config.titleField]),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: (item['_offline_pending'] == true)
                                      ? Text(
                                          [
                                            if (subtitleParts.isNotEmpty)
                                              subtitleParts.join(' · '),
                                            'Waiting to sync',
                                          ].join(' · '),
                                          style: const TextStyle(
                                            color: Colors.orange,
                                          ),
                                        )
                                      : (_isEducation
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (subtitleParts.isNotEmpty)
                                                    Text(
                                                      subtitleParts.join(' · '),
                                                    ),
                                                  const SizedBox(height: 6),
                                                  _EducationStatusChip(
                                                    label: _formatValue(
                                                      item['status'] ??
                                                          'planned',
                                                    ),
                                                    color:
                                                        _educationStatusColor(
                                                          item['status']
                                                              ?.toString(),
                                                        ),
                                                  ),
                                                ],
                                              )
                                            : (subtitleParts.isEmpty
                                                  ? null
                                                  : Text(
                                                      subtitleParts.join(' · '),
                                                    ))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (config.amountField != null &&
                                          item[config.amountField!] != null)
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 100,
                                          ),
                                          child: Text(
                                            (BrandingService.cached ??
                                                    BrandingInfo(siteName: ''))
                                                .formatMoney(
                                                  double.tryParse(
                                                        item[config
                                                                .amountField!]
                                                            .toString(),
                                                      ) ??
                                                      0,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.danger,
                                          size: 20,
                                        ),
                                        tooltip: 'Delete',
                                        onPressed: () async {
                                          if (await _confirmDelete(item)) {
                                            await _delete(item);
                                          }
                                        },
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.black38,
                                      ),
                                    ],
                                  ),
                                  onLongPress: () =>
                                      setState(() => _selectedIds.add(item.id)),
                                  onTap: () {
                                    if (_selectedIds.isNotEmpty) {
                                      setState(() {
                                        if (_selectedIds.contains(item.id)) {
                                          _selectedIds.remove(item.id);
                                        } else {
                                          _selectedIds.add(item.id);
                                        }
                                      });
                                    } else {
                                      _openForm(existing: item);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EducationStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _EducationStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DynamicForm extends StatefulWidget {
  final ModuleConfig config;
  final DynamicItem? existing;
  final VoidCallback onSaved;

  const _DynamicForm({
    required this.config,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<_DynamicForm> {
  late final DynamicCrudService _service = DynamicCrudService(
    widget.config.endpoint,
  );
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, DateTime?> _dateValues = {};
  final Map<String, String?> _selectValues = {};
  final Map<String, List<FieldOption>> _dynamicOptions = {};
  final Set<String> _loadingOptions = {};
  bool _saving = false;
  String? _error;

  bool _projectReminderEnabled = false;
  String _projectReminderOffset = '15';
  DateTime? _projectReminderCustomAt;
  TimeOfDay? _projectDueTime;
  String _projectReminderChannel = 'push';

  @override
  void initState() {
    super.initState();
    for (final field in widget.config.fields) {
      final existingValue = widget.existing?[field.name];
      switch (field.type) {
        case FieldType.date:
          _dateValues[field.name] = existingValue != null
              ? DateTime.tryParse(existingValue.toString())
              : null;
          break;
        case FieldType.datetime:
          _dateValues[field.name] = existingValue != null
              ? DateTime.tryParse(existingValue.toString())?.toLocal()
              : null;
          break;
        case FieldType.select:
          _selectValues[field.name] = existingValue?.toString();
          if (field.optionsEndpoint != null) {
            _loadOptionsFor(field);
          }
          break;
        default:
          _controllers[field.name] = TextEditingController(
            text: existingValue?.toString() ?? '',
          );
      }
    }

    if (widget.config.endpoint == 'project-tasks') {
      final existing = widget.existing;
      _projectReminderEnabled = _truthy(existing?['reminder_enabled']);
      _projectReminderOffset = existing?['reminder_custom_at'] != null
          ? 'custom'
          : (existing?['reminder_offset_minutes'] ?? 15).toString();
      _projectReminderCustomAt = DateTime.tryParse(
        existing?['reminder_custom_at']?.toString() ?? '',
      );
      _projectDueTime = _parseTime(existing?['due_time']);
      _projectReminderChannel = (existing?['reminder_channel'] ?? 'push')
          .toString();
    }
  }

  /// Fetches the real records behind a dynamic select field — e.g.
  /// Savings Contributions' "Savings Goal" listing the user's own
  /// savings-goals records, matching the web app's withGoalOptions().
  Future<void> _loadOptionsFor(FieldConfig field) async {
    setState(() => _loadingOptions.add(field.name));
    try {
      final items = await DynamicCrudService(field.optionsEndpoint!).list();
      if (!mounted) return;
      setState(() {
        final options = items
            .map(
              (item) => FieldOption(
                item.id.toString(),
                (item[field.optionsLabelField] ??
                        item['title'] ??
                        item['name'] ??
                        '#${item.id}')
                    .toString(),
              ),
            )
            .toList();

        final selected = _selectValues[field.name];
        if (selected != null &&
            selected.isNotEmpty &&
            !options.any((option) => option.value == selected)) {
          options.insert(
            0,
            FieldOption(
              selected,
              (widget.existing?[field.optionsLabelField] ??
                      widget.existing?['personal_goal_title'] ??
                      widget.existing?['goal_title'] ??
                      'Linked goal #$selected')
                  .toString(),
            ),
          );
        }

        _dynamicOptions[field.name] = options;
        _loadingOptions.remove(field.name);
      });
    } on ApiException catch (_) {
      if (mounted) setState(() => _loadingOptions.remove(field.name));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(FieldConfig field) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateValues[field.name] ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null) return;
    if (!mounted) return;

    if (field.type == FieldType.datetime) {
      final time = await showTimePicker(
        context: context,
        initialTime: _dateValues[field.name] != null
            ? TimeOfDay.fromDateTime(_dateValues[field.name]!)
            : TimeOfDay.now(),
      );
      if (time == null) return;
      setState(
        () => _dateValues[field.name] = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    } else {
      setState(() => _dateValues[field.name] = date);
    }
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const {
      '1',
      'true',
      'yes',
      'on',
      'enabled',
    }.contains(value?.toString().trim().toLowerCase());
  }

  TimeOfDay? _parseTime(dynamic value) {
    final text = value?.toString() ?? '';
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _formatApiTime(TimeOfDay? value) {
    if (value == null) return null;
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickProjectDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _projectDueTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _projectDueTime = picked);
  }

  Future<void> _pickProjectReminderCustom() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _projectReminderCustomAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_projectReminderCustomAt ?? now),
    );
    if (time == null) return;
    setState(
      () => _projectReminderCustomAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};

    for (final field in widget.config.fields) {
      switch (field.type) {
        case FieldType.date:
          final value = _dateValues[field.name];
          payload[field.name] = value != null
              ? DateFormat('yyyy-MM-dd').format(value)
              : null;
          break;
        case FieldType.datetime:
          final value = _dateValues[field.name];
          payload[field.name] = value?.toIso8601String();
          break;
        case FieldType.select:
          payload[field.name] = _selectValues[field.name];
          break;
        case FieldType.number:
          final text = _controllers[field.name]?.text.trim() ?? '';
          payload[field.name] = text.isEmpty ? null : num.tryParse(text);
          break;
        default:
          final text = _controllers[field.name]?.text.trim() ?? '';
          payload[field.name] = text.isEmpty ? null : text;
      }
    }

    if (widget.config.endpoint == 'project-tasks') {
      if (!payload.containsKey('progress_percent')) {
        final status = (payload['status'] ?? '').toString();
        payload['progress_percent'] = status == 'completed'
            ? 100
            : int.tryParse(
                    _controllers['progress_percent']?.text.trim() ?? '',
                  ) ??
                  (int.tryParse(
                        '${widget.existing?['progress_percent'] ?? 0}',
                      ) ??
                      0);
      }
      payload['due_time'] = _formatApiTime(_projectDueTime);
      payload['reminder_enabled'] = _projectReminderEnabled;
      payload['reminder_offset_minutes'] =
          _projectReminderEnabled && _projectReminderOffset != 'custom'
          ? int.tryParse(_projectReminderOffset)
          : null;
      payload['reminder_custom_at'] =
          _projectReminderEnabled && _projectReminderOffset == 'custom'
          ? _projectReminderCustomAt?.toIso8601String()
          : null;
      payload['reminder_channel'] = _projectReminderEnabled
          ? _projectReminderChannel
          : null;
    }

    return payload;
  }

  Future<void> _save() async {
    // Client-side required-field check mirrors the server's own
    // validation ($rules on the matching Api\{Module}Controller) closely
    // enough to catch the common case before a round-trip, but the
    // server's response is still what actually decides — see the
    // ApiException catch below for anything this misses.
    for (final field in widget.config.fields) {
      if (!field.required) continue;
      final isEmpty = switch (field.type) {
        FieldType.date || FieldType.datetime => _dateValues[field.name] == null,
        FieldType.select =>
          _selectValues[field.name] == null ||
              _selectValues[field.name]!.isEmpty,
        _ => (_controllers[field.name]?.text.trim() ?? '').isEmpty,
      };
      if (isEmpty) {
        setState(() => _error = '${field.label} is required.');
        return;
      }
    }

    if (widget.config.endpoint == 'project-tasks' && _projectReminderEnabled) {
      if (_projectReminderOffset != 'custom' && _projectDueTime == null) {
        setState(
          () =>
              _error = 'Choose a task time before setting a relative reminder.',
        );
        return;
      }
      if (_projectReminderOffset == 'custom' &&
          _projectReminderCustomAt == null) {
        setState(() => _error = 'Choose the custom reminder date and time.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final payload = _buildPayload();
      final saved = widget.existing != null
          ? await _service.update(
              widget.existing!.id,
              payload,
              baseUpdatedAt: widget.existing!['updated_at']?.toString(),
            )
          : await _service.create(payload);
      if (mounted && saved['_offline_pending'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved on this device. It will sync when you reconnect.',
            ),
          ),
        );
      }
      widget.onSaved();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildField(FieldConfig field) {
    switch (field.type) {
      case FieldType.date:
      case FieldType.datetime:
        final value = _dateValues[field.name];
        final formatted = value == null
            ? 'Not set'
            : (field.type == FieldType.date
                  ? DateFormat('yMMMd').format(value)
                  : DateFormat('yMMMd, h:mm a').format(value));
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: Text(formatted),
          trailing: const Icon(Icons.calendar_today),
          onTap: () => _pickDate(field),
        );
      case FieldType.select:
        if (_loadingOptions.contains(field.name)) {
          return InputDecorator(
            decoration: InputDecoration(labelText: field.label),
            child: const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final options = _dynamicOptions[field.name] ?? field.options ?? [];
        return DropdownButtonFormField<String>(
          initialValue: _selectValues[field.name],
          decoration: InputDecoration(labelText: field.label),
          items: options
              .map(
                (option) => DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _selectValues[field.name] = value),
        );
      case FieldType.textarea:
        return VoiceTextField(
          controller: _controllers[field.name]!,
          labelText: field.label,
          hintText: field.hint,
          maxLines: 3,
        );
      case FieldType.number:
        return TextField(
          controller: _controllers[field.name],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
          ),
        );
      case FieldType.text:
        return VoiceTextField(
          controller: _controllers[field.name]!,
          labelText: field.label,
          hintText: field.hint,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing != null
                  ? 'Edit ${widget.config.title}'
                  : 'New ${widget.config.title}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            for (final field in widget.config.fields) ...[
              _buildField(field),
              const SizedBox(height: 12),
            ],
            if (widget.config.endpoint == 'project-tasks') ...[
              const Divider(height: 26),
              if (!widget.config.fields.any(
                (field) => field.name == 'progress_percent',
              )) ...[
                TextField(
                  controller: _controllers.putIfAbsent(
                    'progress_percent',
                    () => TextEditingController(
                      text: '${widget.existing?['progress_percent'] ?? 0}',
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Progress %',
                    hintText: '0 to 100',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Task scheduling',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Task time'),
                subtitle: Text(
                  _projectDueTime == null
                      ? 'Not set'
                      : _projectDueTime!.format(context),
                ),
                onTap: _pickProjectDueTime,
              ),
              Card(
                color: const Color(0xFFFAF5FF),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _projectReminderEnabled,
                        title: const Text(
                          'Set reminder',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'The linked reminder will also appear under Reminders.',
                        ),
                        onChanged: (value) =>
                            setState(() => _projectReminderEnabled = value),
                      ),
                      if (_projectReminderEnabled) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _projectReminderOffset,
                          decoration: const InputDecoration(
                            labelText: 'Remind me',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: '0',
                              child: Text('At task time'),
                            ),
                            DropdownMenuItem(
                              value: '5',
                              child: Text('5 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: '15',
                              child: Text('15 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: '30',
                              child: Text('30 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: '60',
                              child: Text('1 hour before'),
                            ),
                            DropdownMenuItem(
                              value: '120',
                              child: Text('2 hours before'),
                            ),
                            DropdownMenuItem(
                              value: '1440',
                              child: Text('1 day before'),
                            ),
                            DropdownMenuItem(
                              value: 'custom',
                              child: Text('Custom date & time'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _projectReminderOffset = value ?? '15',
                          ),
                        ),
                        if (_projectReminderOffset == 'custom')
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.alarm_outlined),
                            title: const Text('Custom reminder'),
                            subtitle: Text(
                              _projectReminderCustomAt == null
                                  ? 'Choose date and time'
                                  : DateFormat(
                                      'dd MMM yyyy, h:mm a',
                                    ).format(_projectReminderCustomAt!),
                            ),
                            onTap: _pickProjectReminderCustom,
                          ),
                        DropdownButtonFormField<String>(
                          initialValue: _projectReminderChannel,
                          decoration: const InputDecoration(
                            labelText: 'Notification channel',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'in_app',
                              child: Text('In-app'),
                            ),
                            DropdownMenuItem(
                              value: 'push',
                              child: Text('Push notification'),
                            ),
                            DropdownMenuItem(
                              value: 'email',
                              child: Text('Email'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _projectReminderChannel = value ?? 'push',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
