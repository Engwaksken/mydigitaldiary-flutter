import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// One shared, already-initialized SpeechToText engine for the whole
/// app — a form with several VoiceTextField instances (common in the
/// generic _DynamicForm) previously created and initialized a
/// SEPARATE native speech engine per field, all competing at once
/// the moment a form opened. That's the most likely explanation for
/// dictation feeling slow to actually start: by the time a user
/// tapped a mic icon, its own engine might still be mid-initialization
/// while four others were also trying to start up. Initializing once,
/// eagerly, and sharing the result means every field's mic tap can go
/// straight to listen() against an engine that's already warm.
class _SharedSpeech {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static Future<bool>? _initFuture;
  static bool isListening = false;

  static Future<bool> ensureInitialized() {
    return _initFuture ??= _speech.initialize();
  }

  static stt.SpeechToText get instance => _speech;
}

/// Mobile equivalent of the web app's mic button on text fields
/// (pmStartDictation() in layouts/app.blade.php) — that one uses the
/// browser's native SpeechRecognition API, which has no equivalent on
/// mobile; this uses the speech_to_text package's on-device
/// recognition instead. Same toggle behavior: tap to start, tap again
/// (or tap a different field's mic) to stop.
class VoiceTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const VoiceTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  State<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends State<VoiceTextField> {
  bool _listening = false;
  bool _available = false;
  String _baseText = '';

  @override
  void initState() {
    super.initState();
    _SharedSpeech.ensureInitialized().then((available) {
      if (mounted) setState(() => _available = available);
    });
  }

  @override
  void dispose() {
    // Only stops the shared engine if THIS field was the one actively
    // listening — leaves it running if the user navigated away while
    // a DIFFERENT field's dictation was in progress.
    if (_listening) {
      _SharedSpeech.instance.stop();
      _SharedSpeech.isListening = false;
    }
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      // Stop is immediate — no engine work needed beyond telling the
      // (already-running) native session to end.
      await _SharedSpeech.instance.stop();
      _SharedSpeech.isListening = false;
      if (mounted) setState(() => _listening = false);
      return;
    }

    // Only one field can actually be listening at a time (it's one
    // shared native engine) — stop any other field's session first so
    // starting this one doesn't get stuck waiting behind it.
    if (_SharedSpeech.isListening) {
      await _SharedSpeech.instance.stop();
    }

    // Appends to whatever was already typed, rather than replacing it
    // — same as the web version, which inserts recognized speech at
    // the cursor instead of clearing the field first.
    _baseText = widget.controller.text;
    final started = await _SharedSpeech.instance.listen(
      onResult: (result) {
        final separator = _baseText.isEmpty || _baseText.endsWith(' ') ? '' : ' ';
        widget.controller.text = '$_baseText$separator${result.recognizedWords}';
      },
    );
    _SharedSpeech.isListening = started;
    if (mounted) setState(() => _listening = started);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        // Not shown at all if the device doesn't support speech
        // recognition — same "hide the whole button" fallback the web
        // version uses for unsupported browsers, rather than showing
        // a button that would just silently fail when tapped.
        suffixIcon: _available
            ? IconButton(
                icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Theme.of(context).colorScheme.primary : null),
                tooltip: _listening ? 'Stop dictation' : 'Start dictation',
                onPressed: _toggleListening,
              )
            : null,
      ),
    );
  }
}
