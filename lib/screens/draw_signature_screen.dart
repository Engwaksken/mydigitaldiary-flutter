import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/signature_service.dart';
import '../services/api_client.dart';

class DrawSignatureScreen extends StatefulWidget {
  const DrawSignatureScreen({super.key});

  @override
  State<DrawSignatureScreen> createState() => _DrawSignatureScreenState();
}

class _DrawSignatureScreenState extends State<DrawSignatureScreen> {
  final _service = SignatureService();
  final _label = TextEditingController();
  final _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = <List<Offset>>[];
  bool _saving = false;

  bool get _hasInk => _strokes.any((stroke) => stroke.isNotEmpty);

  void _start(Offset point) => setState(() => _strokes.add(<Offset>[point]));

  void _move(Offset point) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(point));
  }

  Future<void> _save() async {
    if (!_hasInk || _saving) {
      if (!_hasInk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign inside the box first.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('Could not create signature image.');
      final saved = await _service.saveDrawnSignature(
        pngBytes: data.buffer.asUint8List(),
        label: _label.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save signature: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Draw Signature')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Sign with your finger or pen', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Use your finger on a touchscreen or a stylus/digital pen. You can also use a mouse or trackpad.', style: TextStyle(color: Colors.black54, height: 1.4)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  height: 280,
                  color: Colors.white,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _start(d.localPosition),
                    onPanUpdate: (d) => _move(d.localPosition),
                    child: CustomPaint(
                      painter: _SignaturePainter(_strokes),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => setState(_strokes.clear),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                const Icon(Icons.edit, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                const Flexible(child: Text('Finger, stylus, pen, mouse', style: TextStyle(fontSize: 12, color: Colors.black45))),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Signature name (optional)', hintText: 'e.g. Full signature, Initials', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save Signature'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
