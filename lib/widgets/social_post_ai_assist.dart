import 'package:flutter/material.dart';

import '../services/ai_form_assist_service.dart';

/// Title-driven AI helper for Social Media Planner.
///
/// The title remains user-controlled. AI generates the editable caption,
/// hashtags and supporting fields. It never saves or publishes automatically.
class SocialPostAiAssist extends StatefulWidget {
  final TextEditingController titleController;
  final List<String> platforms;
  final String? mediaType;
  final ValueChanged<Map<String, dynamic>> onDraft;

  const SocialPostAiAssist({
    super.key,
    required this.titleController,
    required this.onDraft,
    this.platforms = const <String>[],
    this.mediaType,
  });

  @override
  State<SocialPostAiAssist> createState() => _SocialPostAiAssistState();
}

class _SocialPostAiAssistState extends State<SocialPostAiAssist> {
  bool _loading = false;
  String? _message;

  Future<void> _generate() async {
    final title = widget.titleController.text.trim();

    if (title.isEmpty) {
      setState(() => _message = 'Enter the post title or topic first.');
      return;
    }

    setState(() {
      _loading = true;
      _message = 'Creating a 3–5 paragraph editable caption...';
    });

    try {
      final draft = await const AiFormAssistService().generate(
        module: 'social-media-planner',
        topic: title,
        context: <String, dynamic>{
          if (widget.platforms.isNotEmpty) 'platforms': widget.platforms,
          if ((widget.mediaType ?? '').isNotEmpty)
            'media_type': widget.mediaType,
        },
      );

      widget.onDraft(draft);

      if (mounted) {
        setState(() {
          _message =
              'Draft ready. Caption and hashtags were populated separately. '
              'Review and edit before saving.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message =
              'AI could not prepare the draft. Your current post was kept.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, size: 18),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'AI Generate from post title',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'AI generates a 3–5 paragraph caption, keeps hashtags separate, '
            'and suggests the objective, media idea and call to action.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(_loading ? 'Generating...' : 'AI Generate'),
          ),
          if ((_message ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _message!,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
