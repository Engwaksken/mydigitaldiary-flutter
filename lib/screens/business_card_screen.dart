import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_card.dart';
import '../services/api_client.dart';
import '../services/business_card_service.dart';

Color _colorFromHex(String hex) {
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  final _service = BusinessCardService();
  BusinessCard? _card;
  bool _loading = true;
  bool _saving = false;
  bool _downloadingPdf = false;
  Uint8List? _serverPhotoBytes;

  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _facebookController = TextEditingController();
  final _twitterController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();

  XFile? _pickedPhoto;
  XFile? _pickedLogo;
  Uint8List? _serverLogoBytes;
  bool _removeLogo = false;
  String _cardColor = '#00897B';
  String _cardColorSecondary = '#73BEB6';

  static const _stickyNoteColors = {
    '#F9A825': 'Yellow',
    '#D81B60': 'Pink',
    '#689F38': 'Green',
    '#0288D1': 'Blue',
    '#EF6C00': 'Orange',
    '#8E24AA': 'Purple',
    '#E64A19': 'Coral',
    '#00897B': 'Mint',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _titleController,
      _companyController,
      _phoneController,
      _whatsappController,
      _emailController,
      _websiteController,
      _addressController,
      _bioController,
      _facebookController,
      _twitterController,
      _linkedinController,
      _instagramController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final card = await _service.show();
      Uint8List? photoBytes;
      if (card?.photoUrl != null) {
        try {
          final bytes = await _service.photoBytes();
          if (bytes.isNotEmpty) photoBytes = Uint8List.fromList(bytes);
        } catch (_) {
          // Keep the form usable even if an older/broken public photo URL exists.
        }
      }
      Uint8List? logoBytes;
      if (card?.logoUrl != null) {
        try {
          final bytes = await _service.logoBytes();
          if (bytes.isNotEmpty) logoBytes = Uint8List.fromList(bytes);
        } catch (_) {}
      }
      if (!mounted) return;
      _applyCard(card);
      setState(() {
        _serverPhotoBytes = photoBytes;
        _serverLogoBytes = logoBytes;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(e.message, error: true);
    }
  }

  void _applyCard(BusinessCard? card) {
    _card = card;
    _nameController.text = card?.name ?? '';
    _titleController.text = card?.title ?? '';
    _companyController.text = card?.company ?? '';
    _phoneController.text = card?.phone ?? '';
    _whatsappController.text = card?.whatsappPhone ?? '';
    _emailController.text = card?.email ?? '';
    _websiteController.text = card?.website ?? '';
    _addressController.text = card?.address ?? '';
    _bioController.text = card?.bio ?? '';
    _facebookController.text = card?.socialLinks['facebook']?.toString() ?? '';
    _twitterController.text = card?.socialLinks['twitter']?.toString() ?? '';
    _linkedinController.text = card?.socialLinks['linkedin']?.toString() ?? '';
    _instagramController.text =
        card?.socialLinks['instagram']?.toString() ?? '';
    _cardColor = card?.cardColor ?? '#00897B';
    _cardColorSecondary = card?.cardColorSecondary ?? '#73BEB6';
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 5),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (picked != null && mounted) setState(() => _pickedPhoto = picked);
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (picked != null && mounted) {
      setState(() {
        _pickedLogo = picked;
        _removeLogo = false;
      });
    }
  }

  String? _nullable(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _message('Name is required.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final draft = BusinessCard(
        name: _nameController.text.trim(),
        title: _nullable(_titleController),
        company: _nullable(_companyController),
        phone: _nullable(_phoneController),
        whatsappPhone: _nullable(_whatsappController),
        email: _nullable(_emailController),
        website: _nullable(_websiteController),
        address: _nullable(_addressController),
        bio: _nullable(_bioController),
        socialLinks: {
          if (_nullable(_facebookController) != null)
            'facebook': _nullable(_facebookController),
          if (_nullable(_twitterController) != null)
            'twitter': _nullable(_twitterController),
          if (_nullable(_linkedinController) != null)
            'linkedin': _nullable(_linkedinController),
          if (_nullable(_instagramController) != null)
            'instagram': _nullable(_instagramController),
        },
        cardColor: _cardColor,
        cardColorSecondary: _cardColorSecondary,
      );

      List<int>? photoBytes;
      if (_pickedPhoto != null) {
        photoBytes = await File(_pickedPhoto!.path).readAsBytes();
        if (photoBytes.isEmpty) {
          throw const FormatException('The selected photo is empty.');
        }
      }

      List<int>? logoBytes;
      if (_pickedLogo != null) {
        logoBytes = await File(_pickedLogo!.path).readAsBytes();
        if (logoBytes.isEmpty) {
          throw const FormatException('The selected logo is empty.');
        }
      }

      final saved = await _service.save(
        draft,
        photoBytes: photoBytes,
        photoFilename: _pickedPhoto?.name,
        logoBytes: logoBytes,
        logoFilename: _pickedLogo?.name,
        removeLogo: _removeLogo && _pickedLogo == null,
      );

      // Re-read after save so the screen uses canonical values and the
      // authenticated photo endpoint rather than a public /storage URL.
      final refreshed = await _service.show() ?? saved;
      Uint8List? refreshedPhotoBytes;
      if (refreshed.photoUrl != null) {
        try {
          final bytes = await _service.photoBytes();
          if (bytes.isNotEmpty) refreshedPhotoBytes = Uint8List.fromList(bytes);
        } catch (_) {}
      }
      Uint8List? refreshedLogoBytes;
      if (refreshed.logoUrl != null) {
        try {
          final bytes = await _service.logoBytes();
          if (bytes.isNotEmpty) refreshedLogoBytes = Uint8List.fromList(bytes);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _pickedPhoto = null;
        _pickedLogo = null;
        _removeLogo = false;
        _serverPhotoBytes = refreshedPhotoBytes;
        _serverLogoBytes = refreshedLogoBytes;
        _applyCard(refreshed);
        _saving = false;
      });
      _message('Business card saved. Your public page and QR code are ready.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final validation =
          e.errors?.values.expand((v) => v is List ? v : [v]).join('\n');
      _message(validation?.isNotEmpty == true ? validation! : e.message,
          error: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Could not save the business card: $e', error: true);
    }
  }

  Future<void> _sharePublicLink() async {
    if (_card?.publicUrl == null) return;
    await SharePlus.instance.share(ShareParams(
        text: _card!.publicUrl!, subject: 'My digital business card'));
  }

  Future<void> _openPublicLink() async {
    final url = _card?.publicUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _message('Could not open the public page.', error: true);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloadingPdf = true);
    try {
      final bytes = await _service.downloadPdfBytes();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/business-card.pdf';
      await File(path).writeAsBytes(bytes);
      if (!mounted) return;
      await SharePlus.instance.share(
          ShareParams(files: [XFile(path)], subject: 'My business card'));
    } on ApiException catch (e) {
      _message(e.message, error: true);
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Card')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_card?.publicUrl != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_card?.qrCodeUrl != null)
                            Image.network(
                              _card!.qrCodeUrl!,
                              width: 180,
                              height: 180,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 80,
                                child: Center(
                                    child: Icon(Icons.qr_code_2, size: 56)),
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Text('Public page generated',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          SelectableText(
                            _card!.publicUrl!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            children: [
                              TextButton.icon(
                                  onPressed: _sharePublicLink,
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share')),
                              TextButton.icon(
                                  onPressed: _openPublicLink,
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('View Page')),
                              TextButton.icon(
                                onPressed:
                                    _downloadingPdf ? null : _downloadPdf,
                                icon: _downloadingPdf
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.picture_as_pdf),
                                label: const Text('PDF'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundImage: _pickedPhoto != null
                          ? FileImage(File(_pickedPhoto!.path))
                          : (_serverPhotoBytes != null
                              ? MemoryImage(_serverPhotoBytes!)
                              : null) as ImageProvider?,
                      child: (_pickedPhoto == null && _serverPhotoBytes == null)
                          ? const Icon(Icons.camera_alt, size: 28)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickLogo,
                        child: _pickedLogo != null
                            ? Image.file(File(_pickedLogo!.path),
                                height: 56,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.business, size: 40))
                            : (_serverLogoBytes != null
                                ? Image.memory(_serverLogoBytes!,
                                    height: 56,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.business, size: 40))
                                : Container(
                                    height: 56,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.business_outlined),
                                        SizedBox(width: 8),
                                        Text('Add Company Logo'),
                                      ],
                                    ),
                                  )),
                      ),
                      if (_pickedLogo == null && _serverLogoBytes != null)
                        TextButton(
                          onPressed: () => setState(() => _removeLogo = true),
                          child: Text(
                            _removeLogo ? 'Logo will be removed on save' : 'Remove logo',
                            style: TextStyle(
                              color: _removeLogo
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _field(_nameController, 'Name *'),
                const SizedBox(height: 12),
                _field(_titleController, 'Job Title'),
                const SizedBox(height: 12),
                _field(_companyController, 'Company'),
                const SizedBox(height: 12),
                _field(_phoneController, 'Phone',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_whatsappController, 'WhatsApp Number',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_emailController, 'Email',
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_websiteController, 'Website',
                    keyboardType: TextInputType.url),
                const SizedBox(height: 12),
                _field(_addressController, 'Address'),
                const SizedBox(height: 12),
                _field(_bioController, 'Short Bio', maxLines: 3),
                const SizedBox(height: 20),
                const Text('Social Links',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _field(_facebookController, 'Facebook',
                    keyboardType: TextInputType.url),
                const SizedBox(height: 12),
                _field(_twitterController, 'X / Twitter',
                    keyboardType: TextInputType.url),
                const SizedBox(height: 12),
                _field(_linkedinController, 'LinkedIn',
                    keyboardType: TextInputType.url),
                const SizedBox(height: 12),
                _field(_instagramController, 'Instagram',
                    keyboardType: TextInputType.url),
                const SizedBox(height: 20),
                const Text('Card Colors',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(
                    'Pick both gradient colors for your public card background.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Primary',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _stickyNoteColors.keys.map((hex) {
                    final selected =
                        _cardColor.toUpperCase() == hex.toUpperCase();
                    return GestureDetector(
                      onTap: () => setState(() => _cardColor = hex),
                      child: Tooltip(
                        message: _stickyNoteColors[hex]!,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _colorFromHex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected
                                    ? Colors.black87
                                    : Colors.transparent,
                                width: 2.5),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Secondary',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _stickyNoteColors.keys.map((hex) {
                    final selected =
                        _cardColorSecondary.toUpperCase() == hex.toUpperCase();
                    return GestureDetector(
                      onTap: () => setState(() => _cardColorSecondary = hex),
                      child: Tooltip(
                        message: _stickyNoteColors[hex]!,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _colorFromHex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected
                                    ? Colors.black87
                                    : Colors.transparent,
                                width: 2.5),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [
                      _colorFromHex(_cardColor),
                      _colorFromHex(_cardColorSecondary)
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save & Generate Card'),
                ),
                if (_card != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        final updated = await _service.togglePublished();
                        if (mounted) setState(() => _card = updated);
                        _message(updated.isPublished
                            ? 'Business card is now public.'
                            : 'Business card is now hidden.');
                      } on ApiException catch (e) {
                        _message(e.message, error: true);
                      }
                    },
                    child: Text(_card!.isPublished
                        ? 'Public — tap to hide'
                        : 'Hidden — tap to make public'),
                  ),
                ],
              ],
            ),
    );
  }
}
