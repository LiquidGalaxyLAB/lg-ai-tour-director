import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help & Support (mockups 24 & 25). "Recording Tours" guide is reframed as
/// "Generating AI Films" per the locked decision.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _guides = <(String, String, IconData, String)>[
    (
      'help_guide_getting_started_title',
      'help_guide_getting_started_subtitle',
      Icons.rocket_launch_outlined,
      'help_guide_getting_started_body',
    ),
    (
      'help_guide_connecting_title',
      'help_guide_connecting_subtitle',
      Icons.cable_rounded,
      'help_guide_connecting_body',
    ),
    (
      'help_guide_ai_films_title',
      'help_guide_ai_films_subtitle',
      Icons.movie_filter_outlined,
      'help_guide_ai_films_body',
    ),
  ];

  static const _troubleshooting = <(String, String)>[
    ('help_trouble_connecting_title', 'help_trouble_connecting_body'),
    ('help_trouble_tour_start_title', 'help_trouble_tour_start_body'),
    ('help_trouble_generation_title', 'help_trouble_generation_body'),
  ];

  static const _aiFilmGuides = <(String, String)>[
    ('help_aifilm_falai_title', 'help_aifilm_falai_body'),
    ('help_aifilm_veo_title', 'help_aifilm_veo_body'),
    ('help_aifilm_kling_title', 'help_aifilm_kling_body'),
    ('help_aifilm_runway_title', 'help_aifilm_runway_body'),
    ('help_aifilm_local_title', 'help_aifilm_local_body'),
    ('help_aifilm_custom_title', 'help_aifilm_custom_body'),
  ];

  static const _supportedProvidersList = 'help_supported_providers_list';

  void _showGuide(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 14),
                  _HelpBody(markdown: body),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('help_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'help_subtitle'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                ),
              ),
              title: Text(
                'help_ai_model_setup'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'help_ai_model_setup_desc'.tr(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/help/ai-setup'),
            ),
          ),
          Text(
            'help_quick_guides'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          for (final (title, subtitle, icon, body) in _guides)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                title: Text(
                  title.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(subtitle.tr()),
                onTap: () => _showGuide(context, title.tr(), body.tr()),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'help_troubleshooting'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          for (final (title, body) in _troubleshooting)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(title.tr(), style: theme.textTheme.titleSmall),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [_HelpBody(markdown: body.tr())],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'help_ai_film_setup_guides'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          for (final (title, body) in _aiFilmGuides)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(title.tr(), style: theme.textTheme.titleSmall),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [_HelpBody(markdown: body.tr())],
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'help_supported_platforms'.tr(),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'help_supported_platforms_desc'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                _HelpBody(markdown: _supportedProvidersList.tr()),
                const SizedBox(height: 10),
                Text(
                  'help_new_providers_note'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('help_more_resources'.tr(),
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'help_more_resources_desc'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _Link(
                  icon: Icons.public,
                  label: 'help_official_website'.tr(),
                  onTap: () => _open(context, 'https://www.liquidgalaxy.eu/'),
                ),
                _Link(
                  icon: Icons.smart_display_rounded,
                  label: 'help_youtube'.tr(),
                  onTap: () => _open(
                    context,
                    'https://www.youtube.com/@AndreuIb%C3%A1%C3%B1ez',
                  ),
                ),
                _Link(
                  icon: Icons.forum,
                  label: 'help_discord'.tr(),
                  onTap: () =>
                      _open(context, 'https://discord.com/invite/peGA5K8tJU'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _open(
                    context,
                    'https://www.liquidgalaxy.eu/2024/05/lg-wiki.html',
                  ),
                  icon: const Icon(Icons.menu_book),
                  label: Text('help_open_documentation'.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpBody extends StatelessWidget {
  const _HelpBody({required this.markdown});
  final String markdown;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final raw in markdown.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      final step = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
      if (step != null) {
        children.add(_HelpStep(number: step.group(1)!, text: step.group(2)!));
      } else if (line.startsWith('- ')) {
        children.add(_HelpBullet(text: line.substring(2)));
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _richLine(context, line),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// A line with inline **bold** segments parsed into spans.
Widget _richLine(BuildContext context, String line) {
  final base = Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45);
  final spans = <TextSpan>[];
  final parts = line.split('**');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    spans.add(
      TextSpan(
        text: parts[i],
        style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
    );
  }
  return Text.rich(TextSpan(style: base, children: spans));
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _richLine(context, text),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpBullet extends StatelessWidget {
  const _HelpBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: _richLine(context, text)),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
