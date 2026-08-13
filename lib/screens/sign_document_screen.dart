import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/signed_document.dart';
import '../services/signature_service.dart';
import '../services/api_client.dart';

/// Mobile equivalent of the web app's document-signing editor —
/// deliberately scoped to a single IMAGE document (JPG/PNG), not PDF.
/// Reverted from an earlier attempt at file_picker (which would have
/// let the picker browse any file type) back to image_picker's
/// gallery picker specifically, after file_picker's exact API didn't
/// match what was assumed and failed to build — given the stamping
/// logic only ever accepted images anyway (see the extension check
/// that used to live in _pickDocument() below), a gallery-only picker
/// that can only select what actually works is the safer choice
/// rather than debugging an unverified package further. The web app's
/// PDF.js-based multi-page editor isn't something this port attempts
/// to replicate; see SignatureController::stampImage() on the Laravel
/// side for the full reasoning. Signing one scanned or photographed
/// document — a genuinely common case — works the same way: pick a
/// saved signature, drag it into place on the image, then submit.
class SignDocumentScreen extends StatefulWidget {
  const SignDocumentScreen({super.key});

  @override
  State<SignDocumentScreen> createState() => _SignDocumentScreenState();
}

class _SignDocumentScreenState extends State<SignDocumentScreen> {
  final _service = SignatureService();
  List<SavedSignature> _signatures = [];
  SavedSignature? _selectedSignature;
  XFile? _documentFile;
  bool _loadingSignatures = true;
  final Map<int, Future<List<int>>> _signatureImageFutures = {};
  bool _submitting = false;

  // Signature overlay position/size, as fractions (0.0-1.0) of the
  // document image's displayed box - converted to percentages at
  // submit time, matching the coordinate system the web editor uses.
  double _sigLeftFraction = 0.35;
  double _sigTopFraction = 0.75;
  final double _sigWidthFraction = 0.3;

  final _imageBoxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }


  Widget _signaturePreview(SavedSignature signature) {
    final future = _signatureImageFutures.putIfAbsent(
      signature.id,
      () => _service.signatureImageBytes(signature.id),
    );
    return FutureBuilder<List<int>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return Image.memory(Uint8List.fromList(snapshot.data!), fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
  }

  Future<void> _loadSignatures() async {
    try {
      final signatures = await _service.signatures();
      setState(() {
        _signatures = signatures;
        _selectedSignature = signatures.isNotEmpty ? signatures.first : null;
        _loadingSignatures = false;
      });
    } on ApiException catch (e) {
      setState(() => _loadingSignatures = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickDocument() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) setState(() => _documentFile = picked);
  }

  void _updateDragPosition(DragUpdateDetails details) {
    final box = _imageBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      _sigLeftFraction = (local.dx / box.size.width - _sigWidthFraction / 2).clamp(0.0, 1.0 - _sigWidthFraction);
      _sigTopFraction = (local.dy / box.size.height - 0.08).clamp(0.0, 0.9);
    });
  }

  Future<void> _submit() async {
    if (_documentFile == null || _selectedSignature == null) return;

    setState(() => _submitting = true);
    try {
      final bytes = await File(_documentFile!.path).readAsBytes();
      final result = await _service.stampImage(
        documentBytes: bytes,
        documentFilename: _documentFile!.name,
        signatureId: _selectedSignature!.id,
        xPercent: _sigLeftFraction * 100,
        yPercent: _sigTopFraction * 100,
        widthPercent: _sigWidthFraction * 100,
        heightPercent: _sigWidthFraction * 40,
      );

      if (!mounted) return;

      if (result['was_stamped'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document signed successfully.')));
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['stamp_error'] ?? 'Could not sign the document.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign a Document')),
      body: _loadingSignatures
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_signatures.isEmpty)
                    const Text('No saved signatures yet — add one from the web app first.')
                  else
                    DropdownButtonFormField<SavedSignature>(
                      initialValue: _selectedSignature,
                      decoration: const InputDecoration(labelText: 'Signature to use'),
                      items: _signatures
                          .map((sig) => DropdownMenuItem(value: sig, child: Text(sig.label)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedSignature = value),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDocument,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_documentFile == null ? 'Choose a document image' : 'Change document'),
                  ),
                  const SizedBox(height: 16),
                  if (_documentFile != null && _selectedSignature != null) ...[
                    const Text('Drag the signature into place:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            key: _imageBoxKey,
                            children: [
                              Positioned.fill(
                                child: Image.file(File(_documentFile!.path), fit: BoxFit.contain),
                              ),
                              Positioned(
                                left: _sigLeftFraction * constraints.maxWidth,
                                top: _sigTopFraction * constraints.maxHeight,
                                width: _sigWidthFraction * constraints.maxWidth,
                                child: GestureDetector(
                                  onPanUpdate: _updateDragPosition,
                                  child: Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.blue, width: 1.5)),
                                    child: _signaturePreview(_selectedSignature!),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign Document'),
                    ),
                  ] else
                    const Expanded(
                      child: Center(child: Text('Choose a document image to get started.', style: TextStyle(color: Colors.grey))),
                    ),
                ],
              ),
            ),
    );
  }
}
