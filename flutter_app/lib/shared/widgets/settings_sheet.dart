import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/theme_provider.dart';

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
                      Text('settings'.tr(), style: theme.textTheme.headlineSmall),
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
              title: 'lg_connection_settings'.tr(),
              subtitle: 'lg_connection_settings_sub'.tr(),
              onTap: () => go('/settings/lg'),
            ),
            _SettingsRow(
              icon: Icons.tune_rounded,
              title: 'advanced_lg_controls'.tr(),
              subtitle: 'advanced_lg_controls_sub'.tr(),
              onTap: () => go('/settings/advanced'),
            ),
            _SettingsRow(
              icon: Icons.smart_toy_outlined,
              title: 'ai_configuration'.tr(),
              subtitle: 'ai_configuration_sub'.tr(),
              onTap: () => go('/settings/ai'),
            ),
            _SettingsRow(
              icon: Icons.movie_creation_outlined,
              title: 'ai_film'.tr(),
              subtitle: 'ai_film_sub'.tr(),
              onTap: () => go('/settings/ai-film'),
            ),
            _SettingsRow(
              icon: Icons.movie_filter_outlined,
              title: 'tour_preferences'.tr(),
              subtitle: 'tour_preferences_sub'.tr(),
              onTap: () => go('/settings/preferences'),
            ),
            _SettingsRow(
              icon: Icons.language_rounded,
              title: 'app_language'.tr(),
              onTap: () => go('/settings/language'),
            ),
            _SettingsRow(
              icon: Icons.palette_outlined,
              title: 'app_theme'.tr(),
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
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
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
