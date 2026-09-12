import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/api_client.dart';

Color _colorFromHex(String hex) {
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

/// Mobile equivalent of the web profile page's Colors tab, plus font
/// family/size — a feature that doesn't exist on web either (see
/// User::FONT_FAMILIES on the Laravel side for why the family list is
/// fixed rather than free text). Same sticky-notes palette as the web
/// app's profile and business card color pickers.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final _service = ProfileService();
  bool _saving = false;

  late String _primary;
  late String _secondary;
  late String _fontFamily;
  late double _fontSize;

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

  static const _fontFamilies = [
    'System',
    'Roboto',
    'Poppins',
    'Lato',
    'Merriweather'
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().user;
    _primary = user?.themeColor ?? '#00897B';
    _secondary = user?.themeColorSecondary ?? '#73BEB6';
    _fontFamily = user?.fontFamily ?? 'Lato';
    _fontSize = (user?.fontSize ?? 100).toDouble();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await _service.updateAppearance(
        themeColor: _primary,
        themeColorSecondary: _secondary,
        fontFamily: _fontFamily,
        fontSize: _fontSize.round(),
      );
      if (!mounted) return;
      // Uses the server's actual returned values (the source of
      // truth) rather than assuming the values just sent were saved
      // exactly as-is.
      setState(() {
        _primary = saved['theme_color'] ?? _primary;
        _secondary = saved['theme_color_secondary'] ?? _secondary;
        _fontFamily = saved['font_family'] ?? _fontFamily;
        _fontSize = (saved['font_size'] ?? _fontSize.round()).toDouble();
      });
      context.read<AuthService>().updateAppearance(
            themeColor: _primary,
            themeColorSecondary: _secondary,
            fontFamily: _fontFamily,
            fontSize: _fontSize.round(),
          );
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Appearance saved.')));
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _colorRow(
      String label, String selected, ValueChanged<String> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _stickyNoteColors.keys.map((hex) {
            final isSelected = selected.toUpperCase() == hex.toUpperCase();
            return GestureDetector(
              onTap: () => onSelect(hex),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _colorFromHex(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isSelected ? Colors.black87 : Colors.transparent,
                      width: 3),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Colors',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Pick both gradient colors — this only changes what you see, not anyone else.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _colorRow(
              'Primary', _primary, (hex) => setState(() => _primary = hex)),
          const SizedBox(height: 16),
          _colorRow('Secondary', _secondary,
              (hex) => setState(() => _secondary = hex)),
          const SizedBox(height: 16),
          Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_colorFromHex(_primary), _colorFromHex(_secondary)],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text('Font Family',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _fontFamily,
            items: _fontFamilies
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (value) => setState(() => _fontFamily = value ?? 'Lato'),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Font Size',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${_fontSize.round()}%',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          Slider(
            value: _fontSize,
            min: 80,
            max: 130,
            divisions: 10,
            label: '${_fontSize.round()}%',
            onChanged: (value) => setState(() => _fontSize = value),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Appearance'),
          ),
        ],
      ),
    );
  }
}
