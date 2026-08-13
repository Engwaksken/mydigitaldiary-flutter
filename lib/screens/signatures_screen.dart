import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/signed_document.dart';
import '../services/signature_service.dart';
import '../services/api_client.dart';
import 'sign_document_screen.dart';

/// Upload, preview, and remove saved signatures directly from mobile
/// (long-press to delete) — the one thing that stays web-only is the
/// full drag-and-drop multi-page signing EDITOR, since it depends on
/// PDF.js rendering pages in a browser, which has no equivalent here
/// without a much bigger, harder-to-verify addition. This screen also
/// lists every signed document, with download/share/delete for each.
class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen> {
  final _service = SignatureService();
  List<SavedSignature> _signatures = [];
  List<SignedDocument> _documents = [];
  bool _loading = true;
  bool _uploadingSignature = false;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  bool _bulkWorking = false;
  final Map<int, Future<List<int>>> _signatureImageFutures = {};

  @override
  void initState() {
    super.initState();
    _load();
  }


  Future<List<int>> _signatureBytes(SavedSignature sig) {
    return _signatureImageFutures.putIfAbsent(sig.id, () => _service.signatureImageBytes(sig.id));
  }

  Widget _signatureImage(SavedSignature sig, {double? width, BoxFit fit = BoxFit.contain}) {
    return FutureBuilder<List<int>>(
      future: _signatureBytes(sig),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(width: width, height: width != null ? 64 : 120, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          return SizedBox(
            width: width,
            height: width != null ? 64 : 120,
            child: Center(
              child: IconButton(
                tooltip: 'Retry signature preview',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() => _signatureImageFutures.remove(sig.id));
                },
              ),
            ),
          );
        }
        return Image.memory(Uint8List.fromList(snapshot.data!), width: width, fit: fit, gaplessPlayback: true);
      },
    );
  }

  void _previewSignature(SavedSignature sig) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: _signatureImage(sig),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final signatures = await _service.signatures();
      final documents = await _service.documents();
      setState(() {
        _signatureImageFutures.clear();
        _signatures = signatures;
        _documents = documents;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _uploadSignature() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    final label = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Name this signature (optional)'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'e.g. Formal, Initials')),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Skip')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Save')),
          ],
        );
      },
    );

    setState(() => _uploadingSignature = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final saved = await _service.uploadSignature(fileBytes: bytes, fileName: picked.name, label: label);
      setState(() {
        _signatureImageFutures.remove(saved.id);
        _signatures = [saved, ..._signatures];
        _uploadingSignature = false;
      });
    } on ApiException catch (e) {
      setState(() => _uploadingSignature = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteSignature(SavedSignature sig) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this signature?'),
        content: const Text("It can't be used for signing documents once removed."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteSignature(sig.id);
      _signatureImageFutures.remove(sig.id);
      setState(() => _signatures.removeWhere((s) => s.id == sig.id));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _download(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _delete(SignedDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this document?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteDocument(doc.id);
      setState(() => _documents.removeWhere((d) => d.id == doc.id));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// [doc.downloadUrl] is a direct storage link, not an API route — a
  /// plain HTTP GET works here without the app's Bearer token, same
  /// as opening it in a browser would.
  Future<File> _downloadToTempFile(SignedDocument doc) async {
    final response = await http.get(Uri.parse(doc.downloadUrl));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${doc.originalFilename}');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<void> _shareOne(SignedDocument doc) async {
    try {
      final file = await _downloadToTempFile(doc);
      // Same share_plus API-version uncertainty flagged elsewhere in
      // this app — if this doesn't compile, use
      // Share.shareXFiles([XFile(file.path)]) instead.
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
    }
  }

  void _toggleSelected(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  Future<void> _bulkShare() async {
    setState(() => _bulkWorking = true);
    try {
      final docs = _documents.where((d) => _selectedIds.contains(d.id));
      final files = <XFile>[];
      for (final doc in docs) {
        final file = await _downloadToTempFile(doc);
        files.add(XFile(file.path));
      }
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: files));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
    } finally {
      if (mounted) setState(() => _bulkWorking = false);
    }
  }

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} document(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _bulkWorking = true);
    try {
      await _service.bulkDeleteDocuments(_selectedIds.toList());
      setState(() {
        _documents.removeWhere((d) => _selectedIds.contains(d.id));
        _selectedIds.clear();
        _selectionMode = false;
        _bulkWorking = false;
      });
    } on ApiException catch (e) {
      setState(() => _bulkWorking = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  icon: _bulkWorking ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.share),
                  onPressed: _bulkWorking || _selectedIds.isEmpty ? null : _bulkShare,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _bulkWorking || _selectedIds.isEmpty ? null : _bulkDelete,
                ),
              ],
            )
          : AppBar(title: const Text('Signatures')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('My Signatures', style: Theme.of(context).textTheme.titleMedium),
                        TextButton.icon(
                          onPressed: _uploadingSignature ? null : _uploadSignature,
                          icon: _uploadingSignature
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                  if (_signatures.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('No signatures saved yet — tap "Add" to upload one.'))
                  else
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _signatures.length,
                        itemBuilder: (context, index) {
                          final sig = _signatures[index];
                          return GestureDetector(
                            onTap: () => _previewSignature(sig),
                            onLongPress: () => _deleteSignature(sig),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                              child: _signatureImage(sig, width: 100),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_signatures.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text('Long-press a signature to remove it.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Signed Documents', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (_documents.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Text('No signed documents yet.'))
                  else
                    ..._documents.map((doc) {
                      final isSelected = _selectedIds.contains(doc.id);
                      return ListTile(
                        onTap: _selectionMode ? () => _toggleSelected(doc.id) : null,
                        onLongPress: () => setState(() {
                          _selectionMode = true;
                          _selectedIds.add(doc.id);
                        }),
                        leading: _selectionMode
                            ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelected(doc.id))
                            : Icon(doc.wasStamped ? Icons.check_circle : Icons.description, color: doc.wasStamped ? Colors.green : Colors.grey),
                        title: Text(doc.originalFilename),
                        subtitle: doc.wasStamped
                            ? Text('${doc.placementCount} signature(s) across ${doc.pageCount} page(s)')
                            : (doc.stampError != null ? Text(doc.stampError!, style: const TextStyle(color: Colors.orange)) : null),
                        trailing: _selectionMode
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => _shareOne(doc)),
                                  IconButton(icon: const Icon(Icons.download), onPressed: () => _download(doc.downloadUrl)),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(doc)),
                                ],
                              ),
                      );
                    }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final signed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const SignDocumentScreen()),
          );
          if (signed == true) _load();
        },
        icon: const Icon(Icons.draw),
        label: const Text('Sign a Document'),
      ),
    );
  }
}
