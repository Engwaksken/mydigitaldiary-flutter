import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../models/signed_document.dart';
import '../services/signature_service.dart';
import '../services/api_client.dart';

class SignDocumentScreen extends StatefulWidget {
  const SignDocumentScreen({super.key});

  @override
  State<SignDocumentScreen> createState() => _SignDocumentScreenState();
}

class _SignDocumentScreenState extends State<SignDocumentScreen> {
  final _service = SignatureService();
  List<SavedSignature> _signatures = [];
  SavedSignature? _selectedSignature;
  final List<XFile> _pages = [];
  final Map<int, Offset> _positions = {};
  final Map<int, Future<List<int>>> _signatureImageFutures = {};
  int _currentPage = 0;
  bool _loadingSignatures = true;
  bool _submitting = false;
  bool _scanning = false;
  final double _sigWidthFraction = 0.30;
  final _imageBoxKey = GlobalKey();
  final Map<int, Size> _pageImageSizes = {};
  Rect? _renderedPageRect;

  Offset get _position => _positions[_currentPage] ?? const Offset(.35, .75);

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    try {
      final signatures = await _service.signatures();
      if (!mounted) return;
      setState(() {
        _signatures = signatures;
        _selectedSignature = signatures.isNotEmpty ? signatures.first : null;
        _loadingSignatures = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _loadingSignatures = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _signaturePreview(SavedSignature signature) {
    final future = _signatureImageFutures.putIfAbsent(
        signature.id, () => _service.signatureImageBytes(signature.id));
    return FutureBuilder<List<int>>(
      future: future,
      builder: (context, snapshot) => snapshot.hasData
          ? Image.memory(Uint8List.fromList(snapshot.data!),
              fit: BoxFit.contain, gaplessPlayback: true)
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Future<Size> _readImageSize(XFile file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size =
        Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    frame.image.dispose();
    codec.dispose();
    return size;
  }

  Future<void> _primePageSizes() async {
    final sizes = <int, Size>{};
    for (var i = 0; i < _pages.length; i++) {
      try {
        sizes[i] = await _readImageSize(_pages[i]);
      } catch (_) {
        // Keep the page usable even when dimensions cannot be decoded yet.
      }
    }
    if (!mounted) return;
    setState(() {
      _pageImageSizes
        ..clear()
        ..addAll(sizes);
    });
  }

  Future<void> _pickPages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 86);
    if (picked.isEmpty) return;
    setState(() {
      _pages
        ..clear()
        ..addAll(picked);
      _positions.clear();
      _pageImageSizes.clear();
      _currentPage = 0;
    });
    await _primePageSizes();
  }

  Future<void> _scanPages() async {
    if (_scanning) return;

    if (!Platform.isAndroid) {
      final image = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 86);
      if (image != null && mounted) {
        setState(() {
          _pages
            ..clear()
            ..add(image);
          _positions.clear();
          _pageImageSizes.clear();
          _currentPage = 0;
        });
        await _primePageSizes();
      }
      return;
    }

    setState(() => _scanning = true);
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        // Filter mode keeps crop/cleanup tools but avoids the heavier full
        // editing flow, which makes document capture return much faster.
        mode: ScannerMode.filter,
        pageLimit: 10,
        // Gallery upload already has its own button; disabling it here keeps
        // the scanner UI focused and reduces setup work.
        isGalleryImport: false,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty || !mounted) return;
      final files = images.map((raw) {
        final uri = Uri.tryParse(raw);
        final path =
            uri != null && uri.scheme == 'file' ? uri.toFilePath() : raw;
        return XFile(path);
      }).toList();
      setState(() {
        _pages
          ..clear()
          ..addAll(files);
        _positions.clear();
        _pageImageSizes.clear();
        _currentPage = 0;
      });
      await _primePageSizes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not scan document: $e')),
        );
      }
    } finally {
      await scanner.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _drawSignature() async {
    final bytes = await showDialog<Uint8List>(
        context: context, builder: (_) => const _DrawSignatureDialog());
    if (bytes == null) return;
    try {
      final signature = await _service.uploadSignature(
        fileBytes: bytes,
        fileName:
            'drawn-signature-${DateTime.now().millisecondsSinceEpoch}.png',
        label: 'Drawn Signature',
      );
      if (!mounted) return;
      setState(() {
        _signatures.insert(0, signature);
        _selectedSignature = signature;
      });
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _updateDragPosition(DragUpdateDetails details) {
    final box = _imageBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final pageRect = _renderedPageRect;
    if (box == null ||
        pageRect == null ||
        pageRect.width <= 0 ||
        pageRect.height <= 0) return;

    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      final normalizedX = (local.dx - pageRect.left) / pageRect.width;
      final normalizedY = (local.dy - pageRect.top) / pageRect.height;
      final x = (normalizedX - _sigWidthFraction / 2)
          .clamp(0.0, 1.0 - _sigWidthFraction);
      final y = (normalizedY - .06).clamp(0.0, .88);
      _positions[_currentPage] = Offset(x, y);
    });
  }

  Future<void> _submit() async {
    if (_pages.isEmpty || _selectedSignature == null) return;
    setState(() => _submitting = true);
    final createdIds = <int>[];
    try {
      for (var i = 0; i < _pages.length; i++) {
        final file = _pages[i];
        final pos = _positions[i] ?? const Offset(.35, .75);
        final result = await _service.stampImage(
          documentBytes: await File(file.path).readAsBytes(),
          documentFilename: 'page-${i + 1}-${file.name}',
          signatureId: _selectedSignature!.id,
          xPercent: pos.dx * 100,
          yPercent: pos.dy * 100,
          widthPercent: _sigWidthFraction * 100,
          heightPercent: _sigWidthFraction * 40,
        );
        if (result['was_stamped'] != true)
          throw ApiException(
              422,
              result['stamp_error']?.toString() ??
                  'Page ${i + 1} could not be signed.');
        createdIds.add((result['id'] as num).toInt());
      }

      if (createdIds.length > 1) {
        await _service.bundlePages(createdIds,
            filename:
                'signed-document-${DateTime.now().millisecondsSinceEpoch}.pdf');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(createdIds.length > 1
              ? '${createdIds.length}-page signed PDF saved.'
              : 'Signed document saved.')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _pages.isEmpty ? null : _pages[_currentPage];
    return Scaffold(
      appBar: AppBar(title: const Text('Sign a Document')),
      body: _loadingSignatures
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<SavedSignature>(
                        initialValue: _selectedSignature,
                        decoration:
                            const InputDecoration(labelText: 'Signature'),
                        items: _signatures
                            .map((sig) => DropdownMenuItem(
                                value: sig, child: Text(sig.label)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedSignature = value),
                      ),
                    ),
                    IconButton(
                        onPressed: _drawSignature,
                        tooltip: 'Draw new signature',
                        icon: const Icon(Icons.draw_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _pickPages,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload page(s)'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _scanning ? null : _scanPages,
                            icon: _scanning
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.document_scanner_outlined),
                            label: Text(_scanning
                                ? 'Opening scanner…'
                                : 'Scan page(s)'))),
                  ]),
                  if (_pages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      IconButton(
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          icon: const Icon(Icons.chevron_left)),
                      Expanded(
                          child: Text(
                              'Page ${_currentPage + 1} of ${_pages.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      IconButton(
                          onPressed: _currentPage + 1 < _pages.length
                              ? () => setState(() => _currentPage++)
                              : null,
                          icon: const Icon(Icons.chevron_right)),
                    ]),
                    const Text(
                        'Preview each scanned/uploaded page here and drag the signature inside the actual page area. The saved position now matches this preview.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                  ],
                  if (current != null && _selectedSignature != null)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final sourceSize = _pageImageSizes[_currentPage];
                          if (sourceSize == null ||
                              sourceSize.width <= 0 ||
                              sourceSize.height <= 0) {
                            return Stack(
                              key: _imageBoxKey,
                              children: [
                                Positioned.fill(
                                    child: Image.file(File(current.path),
                                        fit: BoxFit.contain)),
                                const Positioned.fill(
                                    child: IgnorePointer(
                                        child: Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)))),
                              ],
                            );
                          }

                          final scale = math.min(
                            constraints.maxWidth / sourceSize.width,
                            constraints.maxHeight / sourceSize.height,
                          );
                          final renderedWidth = sourceSize.width * scale;
                          final renderedHeight = sourceSize.height * scale;
                          final pageRect = Rect.fromLTWH(
                            (constraints.maxWidth - renderedWidth) / 2,
                            (constraints.maxHeight - renderedHeight) / 2,
                            renderedWidth,
                            renderedHeight,
                          );
                          _renderedPageRect = pageRect;

                          return Stack(
                            key: _imageBoxKey,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fromRect(
                                rect: pageRect,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black12),
                                    boxShadow: const [
                                      BoxShadow(
                                          blurRadius: 8,
                                          color: Color(0x22000000))
                                    ],
                                  ),
                                  child: Image.file(File(current.path),
                                      fit: BoxFit.fill),
                                ),
                              ),
                              Positioned(
                                left: pageRect.left +
                                    (_position.dx * pageRect.width),
                                top: pageRect.top +
                                    (_position.dy * pageRect.height),
                                width: _sigWidthFraction * pageRect.width,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: _updateDragPosition,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: .10),
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 1.5),
                                    ),
                                    child:
                                        _signaturePreview(_selectedSignature!),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  else
                    const Expanded(
                        child: Center(
                            child: Text(
                                'Upload or scan one or more pages to begin.',
                                style: TextStyle(color: Colors.grey)))),
                  if (_pages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _submitting || _selectedSignature == null
                          ? null
                          : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.preview_outlined),
                      label: Text(_pages.length > 1
                          ? 'Save signed ${_pages.length}-page PDF'
                          : 'Save signed document'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _DrawSignatureDialog extends StatefulWidget {
  const _DrawSignatureDialog();
  @override
  State<_DrawSignatureDialog> createState() => _DrawSignatureDialogState();
}

class _DrawSignatureDialogState extends State<_DrawSignatureDialog> {
  final _boundaryKey = GlobalKey();
  final List<Offset?> _points = [];

  Future<void> _save() async {
    if (_points.whereType<Offset>().isEmpty) return;
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null && mounted)
      Navigator.pop(context, data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Draw Signature'),
        content: SizedBox(
          width: 360,
          height: 220,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              color: Colors.white,
              child: GestureDetector(
                onPanStart: (d) => setState(() => _points.add(d.localPosition)),
                onPanUpdate: (d) =>
                    setState(() => _points.add(d.localPosition)),
                onPanEnd: (_) => setState(() => _points.add(null)),
                child: CustomPaint(
                    painter: _SignaturePainter(_points), size: Size.infinite),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => setState(_points.clear),
              child: const Text('Clear')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Use Signature')),
        ],
      );
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  const _SignaturePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
