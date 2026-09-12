import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/budget_import_draft.dart';
import '../services/api_client.dart';
import '../services/budget_import_service.dart';

enum BudgetImportLaunchMode {
  none,
  file,
  camera,
  gallery,
}

class BudgetImportScreen extends StatefulWidget {
  final BudgetImportLaunchMode launchMode;

  const BudgetImportScreen({
    super.key,
    this.launchMode = BudgetImportLaunchMode.none,
  });

  @override
  State<BudgetImportScreen> createState() => _BudgetImportScreenState();
}

class _BudgetImportScreenState extends State<BudgetImportScreen> {
  final _service = const BudgetImportService();
  final _imagePicker = ImagePicker();

  BudgetImportDraft? _draft;
  bool _loading = false;
  bool _initialActionStarted = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialActionStarted) return;
      _initialActionStarted = true;

      switch (widget.launchMode) {
        case BudgetImportLaunchMode.file:
          _pickFile();
          break;
        case BudgetImportLaunchMode.camera:
          _pickImage(ImageSource.camera);
          break;
        case BudgetImportLaunchMode.gallery:
          _pickImage(ImageSource.gallery);
          break;
        case BudgetImportLaunchMode.none:
          break;
      }
    });
  }

  String _contentTypeForFile(String fileName) {
    final name = fileName.toLowerCase();

    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (name.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.webp')) {
      return 'image/webp';
    }
    if (name.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (name.endsWith('.csv')) {
      return 'text/csv';
    }
    if (name.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (name.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }
    if (name.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (name.endsWith('.doc')) {
      return 'application/msword';
    }

    return 'application/octet-stream';
  }

  Future<void> _extractBytes({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final draft = await _service.extract(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );

      if (!mounted) return;

      if (draft.items.isEmpty) {
        draft.items.add(
          BudgetImportItem(
            category: 'General',
            description: '',
            plannedAmount: 0,
            period: 'monthly',
          ),
        );
      }

      setState(() => _draft = draft);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'My Digital Diary could not extract this budget. Please try another file or image.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2400,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      await _extractBytes(
        bytes: bytes,
        fileName: image.name,
        contentType: _contentTypeForFile(image.name),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = source == ImageSource.camera
            ? 'The camera could not be opened. Check camera permission and try again.'
            : 'The selected photo could not be opened.';
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'xlsx',
          'xls',
          'csv',
          'pdf',
          'doc',
          'docx',
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
        allowMultiple: false,
        withData: true,
      );

      final file = result?.files.single;
      if (file == null) return;

      var bytes = file.bytes;

      if (bytes == null && file.path != null) {
        final picked = XFile(file.path!);
        bytes = await picked.readAsBytes();
      }

      if (bytes == null) {
        if (!mounted) return;
        setState(() {
          _error = 'The selected file could not be read.';
        });
        return;
      }

      await _extractBytes(
        bytes: bytes,
        fileName: file.name,
        contentType: _contentTypeForFile(file.name),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The budget file could not be selected.';
      });
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || draft.items.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _service.confirm(draft);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The extracted budget could not be saved.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editItem(int index) async {
    final draft = _draft;
    if (draft == null || index < 0 || index >= draft.items.length) return;

    final item = draft.items[index];

    final category = TextEditingController(text: item.category);
    final description = TextEditingController(text: item.description);
    final planned = TextEditingController(
      text: item.plannedAmount.toStringAsFixed(0),
    );
    final monthYear = TextEditingController(text: item.monthYear ?? '');
    final notes = TextEditingController(text: item.notes ?? '');

    String period = item.period;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            return AlertDialog(
              title: const Text('Edit budget line'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: planned,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Planned amount'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: period,
                      decoration: const InputDecoration(labelText: 'Period'),
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
                      onChanged: (value) {
                        setLocal(() => period = value ?? 'monthly');
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: monthYear,
                      decoration: const InputDecoration(
                        labelText: 'Budget date / month',
                        hintText: 'YYYY-MM-DD',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      setState(() {
        item.category =
            category.text.trim().isEmpty ? 'General' : category.text.trim();
        item.description = description.text.trim();
        item.plannedAmount = double.tryParse(planned.text.trim()) ?? 0;
        item.period = period;
        item.monthYear =
            monthYear.text.trim().isEmpty ? null : monthYear.text.trim();
        item.notes = notes.text.trim().isEmpty ? null : notes.text.trim();
      });
    }

    category.dispose();
    description.dispose();
    planned.dispose();
    monthYear.dispose();
    notes.dispose();
  }

  void _addRow() {
    setState(() {
      _draft ??= BudgetImportDraft(
        title: 'New Budget',
        currency: 'UGX',
        confidence: 100,
        items: <BudgetImportItem>[],
      );

      _draft!.items.add(
        BudgetImportItem(
          category: 'General',
          description: '',
          plannedAmount: 0,
          period: 'monthly',
        ),
      );
    });
  }

  Widget _sourceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import or Scan Budget'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    draft == null
                        ? 'How would you like to add your budget?'
                        : 'Review extracted budget',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    draft == null
                        ? 'Upload a document, scan a printed budget, or choose a photo. My Digital Diary will extract the budget lines for you to review before saving.'
                        : 'Check each detected line before saving it to your budget.',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  if (draft == null) ...[
                    _sourceCard(
                      icon: Icons.upload_file_outlined,
                      title: 'Upload budget file',
                      subtitle:
                          'Excel, CSV, PDF, Word or an existing image file',
                      onTap: _loading ? null : _pickFile,
                    ),
                    const SizedBox(height: 10),
                    _sourceCard(
                      icon: Icons.document_scanner_outlined,
                      title: 'Scan / take picture',
                      subtitle:
                          'Open the camera and photograph a printed or handwritten budget',
                      onTap: _loading
                          ? null
                          : () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(height: 10),
                    _sourceCard(
                      icon: Icons.photo_library_outlined,
                      title: 'Choose budget photo',
                      subtitle:
                          'Select a budget image already saved on your phone',
                      onTap: _loading
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Extracting budget data…',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFBE123C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (draft != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${draft.title} · ${draft.currency} · '
                              '${draft.items.length} line${draft.items.length == 1 ? '' : 's'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(draft.items.length, (index) {
                      final item = draft.items[index];

                      return Card(
                        child: ListTile(
                          onTap: () => _editItem(index),
                          title: Text(
                            item.category,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${item.description.isEmpty ? 'No description' : item.description}\n'
                            'Planned: ${item.plannedAmount.toStringAsFixed(0)} · ${item.period}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Remove line',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      draft.items.removeAt(index);
                                    });
                                  },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Add budget line'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() {
                                _draft = null;
                                _error = null;
                              });
                            },
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Choose another source'),
                    ),
                  ],
                ],
              ),
            ),
            if (draft != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: _loading || draft.items.isEmpty ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save reviewed budget'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
