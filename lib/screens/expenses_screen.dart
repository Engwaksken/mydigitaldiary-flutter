import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/api_client.dart';
import '../services/branding_service.dart';
import '../widgets/voice_text_field.dart';
import '../widgets/confirm_action_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _service = ExpenseService();
  List<Expense> _expenses = [];
  bool _loading = true;
  final Set<int> _selectedIds = {};
  bool _bulkDeleting = false;

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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Offline. No saved expense list is available yet.')));
      }
    }
  }

  Future<void> _delete(Expense expense) async {
    try {
      await _service.delete(expense.id, updatedAt: expense.updatedAt);
      if (!mounted) return;
      setState(() => _expenses.removeWhere((e) => e.id == expense.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expense deleted.')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<bool> _confirmDelete(Expense expense) => showAppConfirmDialog(
        context,
        title: 'Delete expense?',
        message: 'Delete “${expense.category}”? This action cannot be undone.',
        confirmText: 'Delete expense',
      );

  Future<void> _bulkDeleteSelected() async {
    if (_selectedIds.isEmpty || _bulkDeleting) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete selected expenses?',
      message:
          'You are about to permanently delete ${_selectedIds.length} selected expense${_selectedIds.length == 1 ? '' : 's'}.',
      confirmText: 'Delete selected',
    );
    if (!ok) return;
    setState(() => _bulkDeleting = true);
    try {
      await _service.bulkDelete(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _expenses.removeWhere((e) => _selectedIds.contains(e.id));
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected expenses deleted.')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
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
      appBar: AppBar(
        title: Text(_selectedIds.isEmpty
            ? 'Expenses'
            : '${_selectedIds.length} selected'),
        leading: _selectedIds.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIds.clear())),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              tooltip: 'Delete selected',
              onPressed: _bulkDeleting ? null : _bulkDeleteSelected,
              icon: _bulkDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? null
          : FloatingActionButton(
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
                          Text(
                              '${_expenses.length} ${_expenses.length == 1 ? 'item' : 'items'} · Total shown',
                              style: const TextStyle(color: Colors.black54)),
                          Text(
                            (BrandingService.cached ??
                                    BrandingInfo(siteName: ''))
                                .formatMoney(_total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFFE11D48)),
                          ),
                        ],
                      ),
                    ),
                  if (_expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No expenses yet. Tap + to log one.',
                          textAlign: TextAlign.center),
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
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: _selectedIds.isNotEmpty
                                ? Checkbox(
                                    value: _selectedIds.contains(expense.id),
                                    onChanged: (_) => setState(() {
                                      if (_selectedIds.contains(expense.id)) {
                                        _selectedIds.remove(expense.id);
                                      } else {
                                        _selectedIds.add(expense.id);
                                      }
                                    }),
                                  )
                                : const CircleAvatar(
                                    backgroundColor: Color(0x1AE11D48),
                                    child: Icon(Icons.receipt_long,
                                        color: Color(0xFFE11D48)),
                                  ),
                            title: Text(expense.category,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${DateFormat('yMMMd').format(expense.spentAt)}'
                                  '${expense.paymentMethod != null ? ' · ${expense.paymentMethod}' : ''}',
                                ),
                                if (expense.offlinePending) ...[
                                  const SizedBox(height: 3),
                                  const Text('Waiting to sync',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600)),
                                ],
                                if (expense.items.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Items: ${expense.items.map((item) => item.description.trim()).where((name) => name.isNotEmpty).join(', ')}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (BrandingService.cached ??
                                          BrandingInfo(siteName: ''))
                                      .formatMoney(expense.amount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                                if (_selectedIds.isEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    tooltip: 'Delete expense',
                                    onPressed: () async {
                                      if (await _confirmDelete(expense)) {
                                        await _delete(expense);
                                      }
                                    },
                                  ),
                              ],
                            ),
                            onLongPress: () =>
                                setState(() => _selectedIds.add(expense.id)),
                            onTap: () {
                              if (_selectedIds.isNotEmpty) {
                                setState(() {
                                  if (_selectedIds.contains(expense.id)) {
                                    _selectedIds.remove(expense.id);
                                  } else {
                                    _selectedIds.add(expense.id);
                                  }
                                });
                              } else {
                                _openForm(existing: expense);
                              }
                            },
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
  bool _extractingReceipt = false;
  String? _receiptStatus;
  String? _error;

  // Each row needs its own stable controllers across rebuilds - a
  // small wrapper rather than three separate parallel lists, which
  // would be easy to accidentally get out of sync with each other
  // when adding/removing rows.
  final List<_ItemRowControllers> _itemRows = [];

  @override
  void initState() {
    super.initState();
    _categoryController =
        TextEditingController(text: widget.existing?.category ?? '');
    _amountController =
        TextEditingController(text: widget.existing?.amount.toString() ?? '');
    _paymentMethodController =
        TextEditingController(text: widget.existing?.paymentMethod ?? '');
    _notesController =
        TextEditingController(text: widget.existing?.notes ?? '');
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

  void _addItemRow(
      {String description = '', String quantity = '1', String unitPrice = ''}) {
    setState(() => _itemRows.add(_ItemRowControllers(
          description: TextEditingController(text: description),
          quantity: TextEditingController(text: quantity),
          unitPrice: TextEditingController(text: unitPrice),
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

  Future<void> _chooseReceiptSource() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Scan / Upload Receipt',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'The extracted values are filled into this form for review before saving.'),
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Scan document'),
              subtitle: const Text(
                  'Auto-detect, crop, straighten and enhance the paper'),
              onTap: () => Navigator.pop(ctx, 'scan'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take receipt photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose receipt image'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose PDF or image file'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    try {
      if (choice == 'scan') {
        await _scanDocument();
        return;
      }

      if (choice == 'camera' || choice == 'gallery') {
        final picked = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 90,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        final lower = picked.name.toLowerCase();
        final contentType = lower.endsWith('.png')
            ? 'image/png'
            : lower.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';
        await _extractReceipt(bytes, picked.name, contentType);
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _error = 'Could not read the selected receipt file.');
        return;
      }
      await _extractReceipt(bytes, file.name, _contentTypeFor(file.name));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the receipt: $e');
    }
  }

  Future<void> _scanDocument() async {
    // Google ML Kit's full document-scanner UI is currently Android-only.
    // On other platforms keep the flow usable by falling back to the camera.
    if (!Platform.isAndroid) {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (picked == null) return;
      await _extractReceipt(await picked.readAsBytes(), picked.name,
          _contentTypeFor(picked.name));
      return;
    }

    setState(() {
      _extractingReceipt = true;
      _receiptStatus = 'Opening document scanner...';
      _error = null;
    });

    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        pageLimit: 1,
        mode: ScannerMode.full,
        isGalleryImport: true,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty) {
        if (mounted) {
          setState(() {
            _extractingReceipt = false;
            _receiptStatus = null;
          });
        }
        return;
      }

      final rawPath = images.first;
      final uri = Uri.tryParse(rawPath);
      final path =
          uri != null && uri.scheme == 'file' ? uri.toFilePath() : rawPath;
      final file = File(path);
      if (!await file.exists()) {
        throw Exception(
            'The scanned document could not be read from the device.');
      }

      final bytes = await file.readAsBytes();
      final name =
          'scanned-document-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _extractReceipt(bytes, name, 'image/jpeg');
    } catch (e) {
      if (mounted) {
        setState(() {
          _extractingReceipt = false;
          _error = 'Document scan failed: $e';
        });
      }
    } finally {
      await scanner.close();
    }
  }

  String _contentTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _extractReceipt(
      List<int> bytes, String name, String contentType) async {
    setState(() {
      _extractingReceipt = true;
      _receiptStatus = 'Reading receipt and extracting expense details...';
      _error = null;
    });

    try {
      final data = await _service.extractReceipt(
          bytes: bytes, fileName: name, contentType: contentType);
      if (!mounted) return;
      _applyReceipt(data);
      setState(() {
        _receiptStatus =
            'Receipt extracted. Review the filled details and line items, then tap Save.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Receipt extraction failed: $e');
    } finally {
      if (mounted) setState(() => _extractingReceipt = false);
    }
  }

  void _applyReceipt(Map<String, dynamic> data) {
    final category = data['category']?.toString().trim();
    if (category != null && category.isNotEmpty) {
      _categoryController.text = category;
    }

    final total = data['total'];
    if (total != null) _amountController.text = total.toString();

    final date = DateTime.tryParse(data['spent_at']?.toString() ?? '');
    if (date != null) _spentAt = date;

    final payment = data['payment_method']?.toString().trim();
    if (payment != null && payment.isNotEmpty) {
      _paymentMethodController.text = payment;
    }

    if (_notesController.text.trim().isEmpty) {
      final notes = <String>[];
      final merchant = data['merchant']?.toString().trim();
      final receiptNumber = data['receipt_number']?.toString().trim();
      final extractedNotes = data['notes']?.toString().trim();
      if (merchant != null && merchant.isNotEmpty) {
        notes.add('Merchant: $merchant');
      }
      if (receiptNumber != null && receiptNumber.isNotEmpty) {
        notes.add('Receipt #: $receiptNumber');
      }
      if (extractedNotes != null && extractedNotes.isNotEmpty) {
        notes.add(extractedNotes);
      }
      if (notes.isNotEmpty) _notesController.text = notes.join(' · ');
    }

    final extractedItems = (data['items'] as List?) ?? const [];
    if (extractedItems.isNotEmpty) {
      for (final row in _itemRows) {
        row.dispose();
      }
      _itemRows.clear();
      for (final raw in extractedItems) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        _itemRows.add(_ItemRowControllers(
          description: TextEditingController(
              text: item['description']?.toString() ?? ''),
          quantity:
              TextEditingController(text: item['quantity']?.toString() ?? '1'),
          unitPrice:
              TextEditingController(text: item['unit_price']?.toString() ?? ''),
        ));
      }
    }

    setState(() {});
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

  String _cleanNumber(String value) => value.replaceAll(',', '').trim();

  Future<void> _save() async {
    if (_saving || _extractingReceipt) return;

    final category = _categoryController.text.trim();
    if (category.isEmpty) {
      setState(() => _error =
          'Category is required. Review the extracted category before saving.');
      return;
    }

    final items = <ExpenseItem>[];
    for (var i = 0; i < _itemRows.length; i++) {
      final row = _itemRows[i];
      final description = row.description.text.trim();
      final qtyText = _cleanNumber(row.quantity.text);
      final priceText = _cleanNumber(row.unitPrice.text);

      // Ignore a completely blank manually-added row, but never silently
      // submit a partially extracted row that Laravel will reject.
      if (description.isEmpty && qtyText.isEmpty && priceText.isEmpty) continue;

      final qty = double.tryParse(qtyText);
      final price = double.tryParse(priceText);
      if (description.isEmpty || qty == null || qty <= 0 || price == null) {
        setState(() => _error =
            'Review line item ${i + 1}: description, quantity greater than 0, and unit price are required.');
        return;
      }

      items.add(ExpenseItem(
        description: description,
        quantity: qty.toString(),
        unitPrice: price.toString(),
      ));
    }

    double amount;
    if (items.isNotEmpty) {
      amount = items.fold<double>(0, (sum, item) {
        return sum +
            ((double.tryParse(item.quantity) ?? 0) *
                (double.tryParse(item.unitPrice) ?? 0));
      });
    } else {
      final parsed = double.tryParse(_cleanNumber(_amountController.text));
      if (parsed == null || parsed < 0) {
        setState(() => _error =
            'Enter a valid amount, or add at least one valid line item.');
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
      category: category,
      amount: amount,
      spentAt: _spentAt,
      paymentMethod: _paymentMethodController.text.trim().isEmpty
          ? null
          : _paymentMethodController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      items: items,
      updatedAt: widget.existing?.updatedAt,
    );

    try {
      final saved = widget.existing != null
          ? await _service.update(widget.existing!.id, expense)
          : await _service.create(expense);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved.offlinePending
              ? 'Expense saved on this device. It will sync when you are online.'
              : 'Expense saved successfully.')));
      widget.onSaved();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save expense: $e');
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.04),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.document_scanner_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Scan / Upload Receipt',
                              style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Scan a paper receipt/document with automatic edge detection, or upload a PDF/image. The extracted expense details remain editable before saving.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _extractingReceipt ? null : _chooseReceiptSource,
                    icon: _extractingReceipt
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.camera_alt_outlined),
                    label: Text(_extractingReceipt
                        ? 'Reading document...'
                        : 'Scan / Choose Receipt or Document'),
                  ),
                  if (_receiptStatus != null) ...[
                    const SizedBox(height: 6),
                    Text(_receiptStatus!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            VoiceTextField(
              controller: _categoryController,
              labelText: 'Category',
              hintText: 'e.g. Groceries, Rent, Transport',
            ),
            const SizedBox(height: 12),
            if (_itemRows.isEmpty)
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText:
                      '${(BrandingService.cached ?? BrandingInfo(siteName: '')).currencySymbol} ',
                  helperText:
                      'Leave blank and add line items below instead, if this is a multi-item receipt.',
                ),
              )
            else
              InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Amount (computed from line items)'),
                child: Text(
                  (BrandingService.cached ?? BrandingInfo(siteName: ''))
                      .formatMoney(_computedItemsTotal),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Line Items (optional)',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                TextButton.icon(
                    onPressed: _addItemRow,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Item')),
              ],
            ),
            ..._itemRows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final qty =
                  double.tryParse(row.quantity.text.replaceAll(',', '')) ?? 0;
              final price =
                  double.tryParse(row.unitPrice.text.replaceAll(',', '')) ?? 0;
              final lineTotal = qty * price;
              Widget field(TextEditingController controller, String label,
                  {int flex = 1, TextInputType? keyboardType}) {
                return Expanded(
                  flex: flex,
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    decoration:
                        InputDecoration(labelText: label, isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 430;
                    const numeric =
                        TextInputType.numberWithOptions(decimal: true);
                    if (narrow) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(children: [
                              field(row.description, 'Item', flex: 1),
                              const SizedBox(width: 4),
                              IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _removeItemRow(index))
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              field(row.quantity, 'Quantity',
                                  keyboardType: numeric),
                              const SizedBox(width: 10),
                              field(row.unitPrice, 'Unit Price',
                                  flex: 2, keyboardType: numeric)
                            ]),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                  'Line total: ${(BrandingService.cached ?? BrandingInfo(siteName: '')).formatMoney(lineTotal)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        field(row.description, 'Item', flex: 3),
                        const SizedBox(width: 8),
                        field(row.quantity, 'Quantity', keyboardType: numeric),
                        const SizedBox(width: 8),
                        field(row.unitPrice, 'Unit Price',
                            flex: 2, keyboardType: numeric),
                        IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeItemRow(index)),
                      ],
                    );
                  },
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
              onPressed: (_saving || _extractingReceipt) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stable per-row controllers for one itemized-expense line - kept
/// together rather than as three separate parallel lists, which would
/// be easy to accidentally get out of sync when rows are added/removed.
class _ItemRowControllers {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _ItemRowControllers(
      {required this.description,
      required this.quantity,
      required this.unitPrice});

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
