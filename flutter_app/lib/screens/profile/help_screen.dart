import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Help & Support (mockups 24 & 25). "Recording Tours" guide is reframed as
/// "Generating AI Films" per the locked decision.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _guides = <(String, String, IconData)>[
    ('Getting Started', 'Learn the basics of navigating the interface and setting up your first view.', Icons.rocket_launch_outlined),
    ('Connecting to Liquid Galaxy', 'Step-by-step instructions to link your device to the rig via IP or QR code.', Icons.cable_rounded),
    ('Generating AI Films', 'How to opt into an AI film and share your journey as a reusable tour.', Icons.movie_filter_outlined),
  ];

  static const _troubleshooting = [
    'Liquid Galaxy not connecting',
    'Tour not starting on the rig',
    'AI film not available',
  ];

  void _stub(BuildContext context, String label) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label — coming soon')),
      );

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
                child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
              ),
              title: Text('AI Model Setup (OpenRouter)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                'Create an API key, pick a model, and connect it to the app.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/help/openrouter-setup'),
            ),
          ),
          Text('QUICK GUIDES',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1,
              )),
          const SizedBox(height: 12),
          for (final (title, subtitle, icon) in _guides)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                title: Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text(subtitle),
                onTap: () => _stub(context, title),
              ),
            ),
          const SizedBox(height: 12),
          Text('TROUBLESHOOTING',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1,
              )),
          const SizedBox(height: 8),
          for (final item in _troubleshooting)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(item, style: theme.textTheme.titleSmall),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Detailed guidance for this topic will appear here.',
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
                _Link(icon: Icons.public, label: 'Official Website', onTap: () => _stub(context, 'Official Website')),
                _Link(icon: Icons.menu_book, label: 'Documentation', onTap: () => _stub(context, 'Documentation')),
                _Link(icon: Icons.forum, label: 'Discord', onTap: () => _stub(context, 'Discord')),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _stub(context, 'Documentation'),
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
            Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
