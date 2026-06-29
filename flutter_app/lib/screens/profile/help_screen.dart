import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help & Support (mockups 24 & 25). "Recording Tours" guide is reframed as
/// "Generating AI Films" per the locked decision.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _guides = <(String, String, IconData, String)>[
    (
      'Getting Started',
      'Learn the basics of navigating the interface and setting up your first view.',
      Icons.rocket_launch_outlined,
      'AI Tour Director turns a simple text prompt into a cinematic geographic '
          'tour on your Liquid Galaxy rig.\n'
          '\n'
          '1. **Connect** to your rig using the settings gear icon (see '
          '"Connecting to Liquid Galaxy").\n'
          '2. On the home screen, **type a destination or theme**, such as '
          '"ancient temples of India" or "wonders of the world".\n'
          '3. Tap **Generate Tour** and wait a few seconds while the AI '
          'discovers locations.\n'
          '4. Tap **Start Tour** to launch the experience on the rig.',
    ),
    (
      'Connecting to Liquid Galaxy',
      'Step by step instructions to link your device to the rig via IP or QR code.',
      Icons.cable_rounded,
      'You only need to do this once. Connection details are saved '
          'automatically.\n'
          '\n'
          '1. Tap the **gear icon** on the home screen and open **LG Connection '
          'Settings**.\n'
          "2. Enter your rig's **IP address**, **SSH port** (default **22**), "
          '**username** (default **lg**), and **password**.\n'
          '3. Choose how many **screens** your rig has: **3, 5, or 7**.\n'
          '4. Tap **Connect**. The status dot in the top bar turns **green** '
          'when the link is live.',
    ),
    (
      'Generating AI Films',
      'How to opt into an AI film and share your journey as a reusable tour.',
      Icons.movie_filter_outlined,
      'After generating a tour, tap **Start Tour** on the preview screen. Then:\n'
          '\n'
          '- The app **narrates each location** with AI generated commentary.\n'
          '- The rig **flies through the landmarks** automatically.\n'
          '- Each stop shows an **info panel on the rightmost screen** with an '
          'image and description.\n'
          '- Tours are **saved to your library** after completion and can be '
          '**replayed anytime** without regenerating.',
    ),
  ];

  static const _troubleshooting = <(String, String)>[
    (
      'Liquid Galaxy not connecting',
      '- Make sure your phone and the LG rig are on the **same WiFi '
          'network**.\n'
          '- **Double check the IP address**. Find it by running **hostname -I** '
          'on the LG master machine.\n'
          '- Confirm the **SSH port is 22** and the **username is lg**.\n'
          '- If it times out, tap **Relaunch LG** from Advanced Controls, then '
          'reconnect.\n'
          '- If it still fails, restart **Google Earth** on the rig manually.',
    ),
    (
      'Tour not starting on the rig',
      '- Confirm the connection **status dot is green**.\n'
          '- Tap **Clear KML** from Advanced LG Controls, then launch the tour '
          'again.\n'
          '- Make sure **Set Refresh** has been tapped at least once this '
          'session, the rig needs it to load new KML live.\n'
          '- If the rig is blank, tap **Relaunch LG**, wait about 30 seconds for '
          'Google Earth to restart, then try again.',
    ),
    (
      'AI film not available',
      '- Tour generation needs an **OpenRouter API key** in **Settings → AI '
          'Configuration**.\n'
          '- Check that your key is valid with **Test Connection**.\n'
          '- Make sure your model has **available credits**. The free model '
          '**meta-llama/llama-3.1-8b-instruct:free** works without credits.\n'
          '- If it fails mid tour, tap **retry**, or try a **simpler prompt** '
          'with fewer locations.',
    ),
  ];

  /// Opens a scrollable bottom sheet with the full text of a quick guide.
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
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Guides and troubleshooting for using Tour Director with Liquid Galaxy.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Featured: AI model setup (real, navigable guide).
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
                'AI Model Setup (OpenRouter)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Create an API key, pick a model, and connect it to the app.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/help/openrouter-setup'),
            ),
          ),
          Text(
            'QUICK GUIDES',
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
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(subtitle),
                onTap: () => _showGuide(context, title, body),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'TROUBLESHOOTING',
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
                title: Text(title, style: theme.textTheme.titleSmall),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [_HelpBody(markdown: body)],
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
                Text('More Resources', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  "Can't find what you're looking for? Explore our external "
                  'documentation or join the community.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _Link(
                  icon: Icons.public,
                  label: 'Official Website',
                  onTap: () => _open(context, 'https://www.liquidgalaxy.eu/'),
                ),
                _Link(
                  icon: Icons.smart_display_rounded,
                  label: 'YouTube',
                  onTap: () => _open(
                    context,
                    'https://www.youtube.com/@AndreuIb%C3%A1%C3%B1ez',
                  ),
                ),
                _Link(
                  icon: Icons.forum,
                  label: 'Discord',
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
                  label: const Text('Open Documentation'),
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
