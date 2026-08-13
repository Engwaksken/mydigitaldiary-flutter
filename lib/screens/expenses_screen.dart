import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/api_client.dart';
import '../services/branding_service.dart';
import '../widgets/voice_text_field.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _service = ExpenseService();
  List<Expense> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final expenses = await _service.list();
      setState(() {
        _expenses = expenses;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Expense expense) async {
    try {
      await _service.delete(expense.id);
      if (!mounted) return;
      setState(() => _expenses.removeWhere((e) => e.id == expense.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<bool> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('Delete “${expense.category}”? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    return confirmed == true;
  }

  void _openForm({Expense? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExpenseForm(
        existing: existing,
        onSaved: () {
          Navigator.of(context).pop();
          _load();
        },
      ),
    );
  }

  double get _total => _expenses.fold(0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  if (_expenses.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_expenses.length} ${_expenses.length == 1 ? 'item' : 'items'} · Total shown', style: const TextStyle(color: Colors.black54)),
                          Text(
                            (BrandingService.cached ?? BrandingInfo(siteName: '')).formatMoney(_total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE11D48)),
                          ),
                        ],
                      ),
                    ),
                  if (_expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No expenses yet. Tap + to log one.', textAlign: TextAlign.center),
                    )
                  else
                    ...List.generate(_expenses.length, (index) {
                      final expense = _expenses[index];
                      return Dismissible(
                        key: ValueKey(expense.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          if (await _confirmDelete(expense)) {
                            await _delete(expense);
                          }
                          return false;
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1AE11D48),
                              child: Icon(Icons.receipt_long, color: Color(0xFFE11D48)),
                            ),
                            title: Text(expense.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${DateFormat('yMMMd').format(expense.spentAt)}'
                              '${expense.paymentMethod != null ? ' · ${expense.paymentMethod}' : ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (BrandingService.cached ?? BrandingInfo(siteName: '')).formatMoney(expense.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Delete expense',
                                  onPressed: () async {
                                    if (await _confirmDelete(expense)) await _delete(expense);
                                  },
                                ),
                              ],
                            ),
                            onTap: () => _openForm(existing: expense),
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

class _ExpenseForm extends StatefulWidget {
  final Expense? existing;
  final VoidCallback onSaved;

  const _ExpenseForm({this.existing, required this.onSaved});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _service = ExpenseService();
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _notesController;
  late DateTime _spentAt;
  bool _saving = false;
  String? _error;

  // Each row needs its own stable controllers across rebuilds — a
  // small wrapper rather than three separate parallel lists, which
  // would be easy to accidentally get out of sync with each other
  // when adding/removing rows.
  final List<_ItemRowControllers> _itemRows = [];

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: widget.existing?.category ?? '');
    _amountController = TextEditingController(text: widget.existing?.amount.toString() ?? '');
    _paymentMethodController = TextEditingController(text: widget.existing?.paymentMethod ?? '');
    _notesController = TextEditingController(text: widget.existing?.notes ?? '');
    _spentAt = widget.existing?.spentAt ?? DateTime.now();
    for (final item in widget.existing?.items ?? []) {
      _itemRows.add(_ItemRowControllers(
        description: TextEditingController(text: item.description),
        quantity: TextEditingController(text: item.quantity),
        unitPrice: TextEditingController(text: item.unitPrice),
      ));
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _paymentMethodController.dispose();
    _notesController.dispose();
    for (final row in _itemRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addItemRow() {
    setState(() => _itemRows.add(_ItemRowControllers(
          description: TextEditingController(),
          quantity: TextEditingController(text: '1'),
          unitPrice: TextEditingController(),
        )));
  }

  void _removeItemRow(int index) {
    setState(() {
      _itemRows[index].dispose();
      _itemRows.removeAt(index);
    });
  }

  double get _computedItemsTotal {
    return _itemRows.fold(0.0, (sum, row) {
      final qty = double.tryParse(row.quantity.text) ?? 0;
      final price = double.tryParse(row.unitPrice.text) ?? 0;
      return sum + (qty * price);
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _spentAt = date);
  }

  Future<void> _save() async {
    final items = _itemRows
        .map((row) => ExpenseItem(description: row.description.text.trim(), quantity: row.quantity.text, unitPrice: row.unitPrice.text))
        .where((item) => item.description.isNotEmpty)
        .toList();

    double amount;
    if (items.isNotEmpty) {
      amount = _computedItemsTotal;
    } else {
      final parsed = double.tryParse(_amountController.text);
      if (parsed == null) {
        setState(() => _error = 'Enter a valid amount, or add at least one line item.');
        return;
      }
      amount = parsed;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final expense = Expense(
      id: widget.existing?.id ?? 0,
      category: _categoryController.text.trim(),
      amount: amount,
      spentAt: _spentAt,
      paymentMethod: _paymentMethodController.text.trim().isEmpty ? null : _paymentMethodController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      items: items,
    );

    try {
      if (widget.existing != null) {
        await _service.update(widget.existing!.id, expense);
      } else {
        await _service.create(expense);
      }
      widget.onSaved();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
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
              widget.existing != null ? 'Edit Expense' : 'New Expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            VoiceTextField(
              controller: _categoryController,
              labelText: 'Category',
              hintText: 'e.g. Groceries, Rent, Transport',
            ),
            const SizedBox(height: 12),
            if (_itemRows.isEmpty)
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${(BrandingService.cached ?? BrandingInfo(siteName: '')).currencySymbol} ',
                  helperText: 'Leave blank and add line items below instead, if this is a multi-item receipt.',
                ),
              )
            else
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Amount (computed from line items)'),
                child: Text(
                  (BrandingService.cached ?? BrandingInfo(siteName: '')).formatMoney(_computedItemsTotal),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Line Items (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                TextButton.icon(onPressed: _addItemRow, icon: const Icon(Icons.add, size: 16), label: const Text('Add Item')),
              ],
            ),
            ..._itemRows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: row.description,
                        decoration: const InputDecoration(labelText: 'Item', isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: row.quantity,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.unitPrice,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Unit Price', isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeItemRow(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat('yMMMd').format(_spentAt)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            VoiceTextField(
              controller: _paymentMethodController,
              labelText: 'Payment method (optional)',
              hintText: 'e.g. Cash, Card, Mobile Money',
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _notesController,
              labelText: 'Notes (optional)',
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stable per-row controllers for one itemized-expense line — kept
/// together rather than as three separate parallel lists, which would
/// be easy to accidentally get out of sync when rows are added/removed.
class _ItemRowControllers {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _ItemRowControllers({required this.description, required this.quantity, required this.unitPrice});

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
