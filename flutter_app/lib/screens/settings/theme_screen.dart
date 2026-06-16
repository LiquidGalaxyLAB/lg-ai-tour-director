import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';

/// App Theme picker: System / Light / Dark, persisted via [themeModeProvider].
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  static const _options = <(ThemeMode, String, String, IconData)>[
    (ThemeMode.system, 'System Default', 'Match your device setting', Icons.brightness_auto_rounded),
    (ThemeMode.light, 'Light Mode', 'Always use the light theme', Icons.light_mode_rounded),
    (ThemeMode.dark, 'Dark Mode', 'Always use the dark theme', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('App Theme')),
      body: RadioGroup<ThemeMode>(
        groupValue: current,
        onChanged: (m) {
          if (m != null) ref.read(themeModeProvider.notifier).setMode(m);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (mode, title, subtitle, icon) in _options)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: current == mode
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: current == mode ? 1.5 : 1,
                  ),
                ),
                child: RadioListTile<ThemeMode>(
                  value: mode,
                  secondary: Icon(icon, color: theme.colorScheme.primary),
                  title: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(subtitle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
