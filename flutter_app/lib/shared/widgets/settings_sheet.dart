import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/theme_provider.dart';

/// Opens the Settings modal sheet (mockup screen 17) from the header gear.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    void go(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settings', style: theme.textTheme.headlineSmall),
                      Text(
                        'Liquid Galaxy configuration',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SettingsRow(
              icon: Icons.cable_rounded,
              title: 'LG Connection Settings',
              subtitle: 'Configure LG rig connection',
              onTap: () => go('/settings/lg'),
            ),
            _SettingsRow(
              icon: Icons.tune_rounded,
              title: 'Advanced LG Controls',
              subtitle: 'System commands for the rig',
              onTap: () => go('/settings/advanced'),
            ),
            _SettingsRow(
              icon: Icons.movie_filter_outlined,
              title: 'Tour Preferences',
              subtitle: 'Narration and film settings',
              onTap: () => go('/settings/preferences'),
            ),
            _SettingsRow(
              icon: Icons.language_rounded,
              title: 'App Language',
              trailing: 'English',
              onTap: () => go('/settings/language'),
            ),
            _SettingsRow(
              icon: Icons.palette_outlined,
              title: 'App Theme',
              trailing: _themeLabel(themeMode),
              onTap: () => go('/settings/theme'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing == null
          ? const Icon(Icons.chevron_right)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
      onTap: onTap,
    );
  }
}
