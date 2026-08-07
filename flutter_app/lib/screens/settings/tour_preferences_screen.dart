import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String _voice = 'Default Voice';
  String _language = 'English';

  static const _voices = [
    'Default Voice',
    'English (India) – Female',
    'English (India) – Male',
    'English (US) – Female',
    'English (US) – Male',
  ];
  static const _languages = [
    'English',
    'Spanish',
    'French',
    'Hindi',
    'Arabic',
    'German',
    'Portuguese',
    'Chinese',
  ];

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
      _voice = p.getString('pref_voice') ?? 'Default Voice';
      _language = p.getString('pref_subtitle_language') ?? 'English';
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_voice_narration', _voiceNarration);
    await p.setString('pref_voice', _voice);
    await p.setString('pref_subtitle_language', _language);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('preferences_saved'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('tour_preferences'.tr())),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.movie_creation_outlined),
                    title: Text(
                      'ai_film'.tr(),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('ai_film_pref_subtitle'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/ai-film'),
                  ),
                  const Divider(),
                  _DropdownTile(
                    title: 'Narration Voice',
                    subtitle: 'Select the voice used for tour narration.',
                    value: _voice,
                    items: _voices,
                    onChanged: (v) => setState(() => _voice = v!),
                    comingSoon: true,
                  ),
                  const SizedBox(height: 16),
                  _DropdownTile(
                    title: 'Subtitle Language',
                    subtitle:
                        'Language for the tour narration voice (TTS) and '
                        'subtitles.',
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
                child: Text('save_preferences'.tr()),
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
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: _TitleWithBadge(title: title, comingSoon: false),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Title row with an optional "Coming soon" pill for not-yet-wired settings.
class _TitleWithBadge extends StatelessWidget {
  const _TitleWithBadge({required this.title, required this.comingSoon});
  final String title;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (comingSoon) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Coming soon',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
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
    this.comingSoon = false,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleWithBadge(title: title, comingSoon: comingSoon),
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
          // Disabled until the feature is wired.
          onChanged: comingSoon ? null : onChanged,
        ),
      ],
    );
  }
}
