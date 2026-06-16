import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tour Preferences (mockup 20). "Record Tour" is reframed as the opt-in
/// **Generate AI Film** default. Narration voices are stubbed (OS/device
/// dependent). Persisted to SharedPreferences; promote to a provider when the
/// tour flow consumes these.
class TourPreferencesScreen extends StatefulWidget {
  const TourPreferencesScreen({super.key});

  @override
  State<TourPreferencesScreen> createState() => _TourPreferencesScreenState();
}

class _TourPreferencesScreenState extends State<TourPreferencesScreen> {
  bool _voiceNarration = true;
  bool _showSubtitles = true;
  bool _generateFilm = false;
  String _voice = 'Default Voice';
  String _language = 'English';

  static const _voices = [
    'Default Voice',
    'English (India) – Female',
    'English (India) – Male',
    'English (US) – Female',
    'English (US) – Male',
  ];
  static const _languages = ['English', 'Arabic', 'French', 'Hindi', 'Spanish'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _voiceNarration = p.getBool('pref_voice_narration') ?? true;
      _showSubtitles = p.getBool('pref_show_subtitles') ?? true;
      _generateFilm = p.getBool('pref_generate_film') ?? false;
      _voice = p.getString('pref_voice') ?? 'Default Voice';
      _language = p.getString('pref_subtitle_language') ?? 'English';
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_voice_narration', _voiceNarration);
    await p.setBool('pref_show_subtitles', _showSubtitles);
    await p.setBool('pref_generate_film', _generateFilm);
    await p.setString('pref_voice', _voice);
    await p.setString('pref_subtitle_language', _language);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferences saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tour Preferences')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ToggleTile(
                    title: 'Voice Narration',
                    subtitle: 'Enable AI-generated narration during the tour.',
                    value: _voiceNarration,
                    onChanged: (v) => setState(() => _voiceNarration = v),
                  ),
                  const Divider(),
                  _ToggleTile(
                    title: 'Show Subtitles on LG screens',
                    subtitle: 'Display synchronized subtitles during narration.',
                    value: _showSubtitles,
                    onChanged: (v) => setState(() => _showSubtitles = v),
                  ),
                  const Divider(),
                  _ToggleTile(
                    title: 'Generate AI Film',
                    subtitle:
                        'Offer to create a shareable AI film of the tour (via Veo).',
                    value: _generateFilm,
                    onChanged: (v) => setState(() => _generateFilm = v),
                  ),
                  const Divider(),
                  _DropdownTile(
                    title: 'Narration Voice',
                    subtitle: 'Select the voice used for tour narration.',
                    value: _voice,
                    items: _voices,
                    onChanged: (v) => setState(() => _voice = v!),
                  ),
                  const SizedBox(height: 16),
                  _DropdownTile(
                    title: 'Subtitle Language',
                    subtitle: 'Choose the subtitle language used during the tour.',
                    value: _language,
                    items: _languages,
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save Preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        Text(subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: [
            for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
