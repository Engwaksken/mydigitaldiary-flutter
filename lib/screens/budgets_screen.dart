import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/branding_service.dart';
import 'budget_import_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<Map<String, dynamic>> _budgets = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _debts = <Map<String, dynamic>>[];

  bool _loading = true;
  bool _duplicating = false;
  String? _error;
  final Set<int> _updatingExpenseIds = <int>{};

  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _load();
  }

  String get _selectedMonthKey =>
      DateFormat('yyyy-MM').format(_selectedMonth);

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(
              value?.toString().replaceAll(',', '').trim() ?? '',
            ) ??
            0;

    return (BrandingService.cached ?? BrandingInfo(siteName: ''))
        .formatMoney(amount);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      dynamic response = await ApiClient.instance.get(
        'budgets?month=$_selectedMonthKey',
        cacheable: false,
      );

      final rows = _extractRows(response);

      List<Map<String, dynamic>> debts = <Map<String, dynamic>>[];

      try {
        final debtResponse = await ApiClient.instance.get(
          'budgets/debts',
          cacheable: false,
        );
        debts = _extractRows(debtResponse);
      } catch (_) {
        // Budget listing remains usable if debt lookup is unavailable.
      }

      if (!mounted) return;

      setState(() {
        _budgets = rows;
        _debts = debts;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load budgets right now.';
      });
    }
  }

  List<Map<String, dynamic>> _extractRows(dynamic response) {
    dynamic data = response;

    if (data is Map && data['data'] != null) {
      data = data['data'];
    }

    if (data is Map && data['data'] is List) {
      data = data['data'];
    } else if (data is Map && data['items'] is List) {
      data = data['items'];
    } else if (data is Map && data['records'] is List) {
      data = data['records'];
    }

    if (data is! List) {
      return <Map<String, dynamic>>[];
    }

    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _changeMonth(int offset) async {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });

    await _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
      helpText: 'Choose any date in the budget month',
    );

    if (picked == null) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });

    await _load();
  }

  Future<void> _openImport(BudgetImportLaunchMode mode) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BudgetImportScreen(launchMode: mode),
      ),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _showNewBudgetOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Widget action({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            leading: CircleAvatar(
              child: Icon(icon),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) {
            return Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                      children: [
                        const ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            'New Budget',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                          subtitle: Text(
                            'Create, copy, import or scan a monthly budget.',
                          ),
                        ),
                        action(
                          icon: Icons.copy_all_outlined,
                          title: 'Duplicate monthly budget',
                          subtitle: 'Copy another month and edit only what changed',
                          onTap: _duplicateMonth,
                        ),
                        action(
                          icon: Icons.edit_note_rounded,
                          title: 'Enter manually',
                          subtitle: 'Add one budget line yourself',
                          onTap: _openManualForm,
                        ),
                        action(
                          icon: Icons.upload_file_outlined,
                          title: 'Upload budget file',
                          subtitle: 'Excel, CSV, PDF, Word or image file',
                          onTap: () => _openImport(BudgetImportLaunchMode.file),
                        ),
                        action(
                          icon: Icons.document_scanner_outlined,
                          title: 'Scan / take picture',
                          subtitle: 'Photograph a printed or handwritten budget',
                          onTap: () => _openImport(BudgetImportLaunchMode.camera),
                        ),
                        action(
                          icon: Icons.photo_library_outlined,
                          title: 'Choose budget photo',
                          subtitle: 'Select an existing budget image from your phone',
                          onTap: () => _openImport(BudgetImportLaunchMode.gallery),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _duplicateMonth() async {
    DateTime source = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );
    DateTime target = _selectedMonth;
    String? formError;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setLocal) {
            Future<void> pickSource() async {
              final value = await showDatePicker(
                context: sheetContext,
                initialDate: source,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(
                  const Duration(days: 3650),
                ),
                helpText: 'Choose any date in the source month',
              );

              if (value != null) {
                setLocal(() {
                  source = DateTime(value.year, value.month);
                });
              }
            }

            Future<void> pickTarget() async {
              final value = await showDatePicker(
                context: sheetContext,
                initialDate: target,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(
                  const Duration(days: 3650),
                ),
                helpText: 'Choose any date in the target month',
              );

              if (value != null) {
                setLocal(() {
                  target = DateTime(value.year, value.month);
                });
              }
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 8,
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Text(
                    'Duplicate Monthly Budget',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Every budget item is copied. Expense checkboxes are reset so you can mark spending again in the new month.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_outlined),
                    title: const Text('Copy from'),
                    subtitle: Text(
                      DateFormat('MMMM yyyy').format(source),
                    ),
                    trailing:
                        const Icon(Icons.calendar_month_outlined),
                    onTap: pickSource,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.arrow_forward_rounded),
                    title: const Text('Copy to'),
                    subtitle: Text(
                      DateFormat('MMMM yyyy').format(target),
                    ),
                    trailing:
                        const Icon(Icons.calendar_month_outlined),
                    onTap: pickTarget,
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formError!,
                      style: const TextStyle(
                        color: Color(0xFFBE123C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      if (source.year == target.year &&
                          source.month == target.month) {
                        setLocal(() {
                          formError =
                              'Choose a different target month.';
                        });
                        return;
                      }

                      Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Duplicate Budget'),
                  ),
                ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _duplicating = true);

    try {
      final sourceKey = DateFormat('yyyy-MM').format(source);
      final targetKey = DateFormat('yyyy-MM').format(target);

      await ApiClient.instance.post(
        'budgets/duplicate-month',
        <String, dynamic>{
          'source_month': sourceKey,
          'target_month': targetKey,
        },
      );

      if (!mounted) return;

      setState(() {
        _selectedMonth = target;
      });

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Budget copied. Edit only the items that changed.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _duplicating = false);
      }
    }
  }

  Future<void> _toggleExpensed(
    Map<String, dynamic> budget,
    bool wanted,
  ) async {
    final id = _intId(budget);
    if (id == null || _updatingExpenseIds.contains(id)) return;

    setState(() => _updatingExpenseIds.add(id));

    try {
      dynamic response = await ApiClient.instance.post(
        'budgets/$id/expense-status',
        <String, dynamic>{
          'is_expensed': wanted,
        },
      );

      dynamic updated = response;
      if (updated is Map && updated['data'] is Map) {
        updated = updated['data'];
      }

      if (!mounted) return;

      setState(() {
        final index = _budgets.indexWhere(
          (item) => _intId(item) == id,
        );

        if (index >= 0) {
          if (updated is Map) {
            _budgets[index] =
                Map<String, dynamic>.from(updated);
          } else {
            _budgets[index]['is_expensed'] = wanted;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wanted
                ? ((budget['application_type']?.toString() == 'debt_payment')
                    ? 'Debt reduced and Income balance updated.'
                    : 'Added to Expenses and Income balance updated.')
                : 'Automatic Budget payment reversed.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingExpenseIds.remove(id));
      }
    }
  }

  Future<void> _openManualForm([
    Map<String, dynamic>? existing,
  ]) async {
    final category = TextEditingController(
      text: existing?['category']?.toString() ?? '',
    );
    final amount = TextEditingController(
      text: existing == null
          ? ''
          : _amount(existing).toStringAsFixed(
              _amount(existing).truncateToDouble() == _amount(existing)
                  ? 0
                  : 2,
            ),
    );
    final notes = TextEditingController(
      text: existing?['notes']?.toString() ?? '',
    );

    String period = _normalisePeriod(
      existing?['period']?.toString(),
    );

    DateTime budgetMonth =
        _parseMonth(existing?['month_year']) ?? _selectedMonth;

    bool isExpensed = existing?['is_expensed'] == true ||
        existing?['is_expensed']?.toString() == '1';

    String applicationType =
        existing?['application_type']?.toString() == 'debt_payment'
            ? 'debt_payment'
            : 'expense';

    int? debtId = int.tryParse(
      existing?['debt_id']?.toString() ?? '',
    );

    bool saving = false;
    String? formError;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setLocal) {
            Future<void> pickMonth() async {
              final date = await showDatePicker(
                context: sheetContext,
                initialDate: budgetMonth,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(
                  const Duration(days: 3650),
                ),
                helpText: 'Choose any date in the budget month',
              );

              if (date != null) {
                setLocal(() {
                  budgetMonth = DateTime(
                    date.year,
                    date.month,
                  );
                });
              }
            }

            Future<void> save() async {
              final value = double.tryParse(
                    amount.text
                        .replaceAll(',', '')
                        .trim(),
                  ) ??
                  0;

              if (category.text.trim().isEmpty) {
                setLocal(() {
                  formError = 'Enter a budget category.';
                });
                return;
              }

              if (value <= 0) {
                setLocal(() {
                  formError =
                      'Enter a budgeted amount greater than zero.';
                });
                return;
              }

              if (applicationType == 'debt_payment' &&
                  isExpensed &&
                  debtId == null) {
                setLocal(() {
                  formError =
                      'Select the debt this payment should reduce.';
                });
                return;
              }

              setLocal(() {
                saving = true;
                formError = null;
              });

              final body = <String, dynamic>{
                'category': category.text.trim(),
                'amount': value,
                'period': period,
                'month_year':
                    DateFormat('yyyy-MM').format(budgetMonth),
                'notes': notes.text.trim(),
                'application_type': applicationType,
                'debt_id':
                    applicationType == 'debt_payment' ? debtId : null,
                'is_expensed': isExpensed,
              };

              try {
                if (existing == null) {
                  await ApiClient.instance.post(
                    'budgets',
                    body,
                  );
                } else {
                  await ApiClient.instance.put(
                    'budgets/${existing['id']}',
                    body,
                  );
                }

                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, true);
                }
              } on ApiException catch (e) {
                if (sheetContext.mounted) {
                  setLocal(() {
                    formError = e.message;
                    saving = false;
                  });
                }
              } catch (_) {
                if (sheetContext.mounted) {
                  setLocal(() {
                    formError =
                        'The budget could not be saved.';
                    saving = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                bottom:
                    MediaQuery.viewInsetsOf(sheetContext).bottom +
                    18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? 'Enter Budget'
                          : 'Edit Budget',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText:
                            'e.g. Rent, Food, Transport',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Budgeted amount',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: period,
                      decoration: const InputDecoration(
                        labelText: 'Period',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'annually',
                          child: Text('Annually'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              setLocal(() {
                                period =
                                    value ?? 'monthly';
                              });
                            },
                    ),
                    const SizedBox(height: 6),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Budget month'),
                      subtitle: Text(
                        DateFormat('MMMM yyyy')
                            .format(budgetMonth),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      onTap: saving ? null : pickMonth,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: applicationType,
                      decoration: const InputDecoration(
                        labelText: 'Apply as',
                        helperText:
                            'Choose Expense or Debt Payment.',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'expense',
                          child: Text('Expense'),
                        ),
                        DropdownMenuItem(
                          value: 'debt_payment',
                          child: Text('Debt Payment'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              setLocal(() {
                                applicationType =
                                    value ?? 'expense';

                                if (applicationType !=
                                    'debt_payment') {
                                  debtId = null;
                                }
                              });
                            },
                    ),
                    if (applicationType == 'debt_payment') ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: _debts.any(
                          (debt) => _intId(debt) == debtId,
                        )
                            ? debtId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Debt to pay',
                          helperText:
                              'The payment reduces this outstanding debt.',
                        ),
                        items: _debts
                            .where((debt) => _intId(debt) != null)
                            .map(
                              (debt) => DropdownMenuItem<int>(
                                value: _intId(debt),
                                child: Text(
                                  '${debt['person_name'] ?? 'Debt'} — ${_money(debt['amount'])}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                setLocal(() {
                                  debtId = value;
                                });
                              },
                      ),
                    ],
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity:
                          ListTileControlAffinity.leading,
                      value: isExpensed,
                      title: const Text(
                        'This item has been paid / spent',
                      ),
                      subtitle: Text(
                        applicationType == 'debt_payment'
                            ? 'Checking this reduces the selected debt and updates your Income balance.'
                            : 'Checking this adds it to Expenses and updates your Income balance.',
                      ),
                      onChanged: saving
                          ? null
                          : (value) {
                              setLocal(() {
                                isExpensed = value ?? false;
                              });
                            },
                    ),
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: Color(0xFFBE123C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        saving
                            ? 'Saving…'
                            : 'Save Budget',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    category.dispose();
    amount.dispose();
    notes.dispose();

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(
    Map<String, dynamic> budget,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete budget?'),
          content: Text(
            'Delete ${budget['category'] ?? 'this budget'}? '
            'If it already created an Expense, the Expense is kept as financial history.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiClient.instance.delete(
        'budgets/${budget['id']}',
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  int? _intId(Map<String, dynamic> item) {
    final value = item['id'];

    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  double _amount(Map<String, dynamic>? budget) {
    if (budget == null) return 0;

    for (final key in const [
      'amount',
      'planned_amount',
      'budget_amount',
      'total_amount',
    ]) {
      final value = budget[key];

      if (value is num) return value.toDouble();

      final parsed =
          double.tryParse(value?.toString() ?? '');

      if (parsed != null) return parsed;
    }

    return 0;
  }

  bool _isExpensed(Map<String, dynamic> budget) {
    final value = budget['is_expensed'];

    return value == true ||
        value == 1 ||
        value?.toString() == '1' ||
        budget['expense'] is Map;
  }

  String _normalisePeriod(String? value) {
    const values = [
      'weekly',
      'monthly',
      'annually',
    ];

    return values.contains(value) ? value! : 'monthly';
  }

  DateTime? _parseMonth(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();

    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(raw)) {
      final parts = raw.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    final total = _budgets.fold<double>(
      0,
      (sum, row) => sum + _amount(row),
    );

    final expensedCount =
        _budgets.where(_isExpensed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            tooltip: 'Duplicate monthly budget',
            onPressed: _duplicating
                ? null
                : _duplicateMonth,
            icon: _duplicating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Refresh budgets',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewBudgetOptions,
        icon: const Icon(Icons.add),
        label: const Text('New Budget'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            14,
            14,
            14,
            100,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: _pickMonth,
                          borderRadius:
                              BorderRadius.circular(12),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('MMMM yyyy')
                                      .format(
                                    _selectedMonth,
                                  ),
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const Text(
                                  'Tap to choose month',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryValue(
                          label: 'Budgeted',
                          value: _money(total),
                        ),
                      ),
                      Expanded(
                        child: _SummaryValue(
                          label: 'Items',
                          value: '${_budgets.length}',
                        ),
                      ),
                      Expanded(
                        child: _SummaryValue(
                          label: 'Expensed',
                          value:
                              '$expensedCount/${_budgets.length}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed:
                  _duplicating ? null : _duplicateMonth,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text(
                'Duplicate another month into this month',
              ),
            ),
            const SizedBox(height: 12),

            if (_loading && _budgets.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null && _budgets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 46,
                      color: Color(0xFFBE123C),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_budgets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 50,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No budget for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Duplicate a previous month, enter items manually, upload a file, or scan a budget.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _showNewBudgetOptions,
                      icon: const Icon(Icons.add),
                      label:
                          const Text('Create Budget'),
                    ),
                  ],
                ),
              )
            else
              ..._budgets.map((budget) {
                final id = _intId(budget);
                final expensed = _isExpensed(budget);
                final updating = id != null &&
                    _updatingExpenseIds.contains(id);

                final category =
                    budget['category']?.toString().trim() ??
                        'Budget';
                final notes =
                    budget['notes']?.toString().trim() ??
                        '';

                return Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      4,
                      4,
                      4,
                      4,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        updating
                            ? const SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Checkbox(
                                value: expensed,
                                onChanged: (value) {
                                  _toggleExpensed(
                                    budget,
                                    value ?? false,
                                  );
                                },
                              ),
                        Expanded(
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            onTap: () =>
                                _openManualForm(budget),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    category,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  _money(
                                    _amount(budget),
                                  ),
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              [
                                expensed
                                    ? 'In Expenses'
                                    : 'Not expensed',
                                if (notes.isNotEmpty)
                                  notes,
                              ].join(' · '),
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color: expensed
                                    ? const Color(
                                        0xFF047857,
                                      )
                                    : const Color(
                                        0xFF64748B,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openManualForm(budget);
                            } else if (value ==
                                'delete') {
                              _delete(budget);
                            }
                          },
                          itemBuilder: (_) =>
                              const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                leading: Icon(
                                  Icons.edit_outlined,
                                ),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                leading: Icon(
                                  Icons.delete_outline,
                                ),
                                title: Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
