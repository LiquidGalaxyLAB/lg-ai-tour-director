import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Temporary Phase-0 sample screen to approve the M3 theme before applying it
/// app-wide. Toggle brightness and cycle the candidate display fonts live.
/// Remove this screen + its route once the theme is signed off.
class ThemePreviewScreen extends StatefulWidget {
  const ThemePreviewScreen({super.key});

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen> {
  static const _fonts = ['Poppins', 'Lexend', 'Manrope', 'Roboto'];
  String _font = 'Poppins';
  bool _dark = false;
  int _navIndex = 0;
  bool _switchOn = true;

  @override
  Widget build(BuildContext context) {
    final theme = _dark
        ? AppTheme.dark(displayFont: _font)
        : AppTheme.light(displayFont: _font);

    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Theme Preview'),
              actions: [
                IconButton(
                  icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => setState(() => _dark = !_dark),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _navIndex,
              onDestinationSelected: (i) => setState(() => _navIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  label: 'Saved',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  label: 'Tours',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Display font (tap to compare)'),
                Wrap(
                  spacing: 8,
                  children: _fonts.map((f) {
                    return ChoiceChip(
                      label: Text(f),
                      selected: _font == f,
                      onSelected: (_) => setState(() => _font = f),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                _section('Typography'),
                Text('Where to next?', style: text.headlineMedium),
                Text('Saved Tours', style: text.headlineSmall),
                Text('Tour Director', style: text.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Built in 1732 as the seat of the Peshwas, Shaniwar Wada '
                  'once stood as the political heart of the Maratha Empire.',
                  style: text.bodyMedium,
                ),
                Text('QUICK LAUNCH', style: text.labelMedium),
                const SizedBox(height: 24),

                _section('Brand colors'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _Swatch('Primary', AppColors.googleBlue),
                    _Swatch('Red', AppColors.googleRed),
                    _Swatch('Yellow', AppColors.googleYellow),
                    _Swatch('Green', AppColors.googleGreen),
                    _Swatch('Orange', AppColors.tileSetRefresh),
                    _Swatch('Purple', AppColors.tileClearLogo),
                  ],
                ),
                const SizedBox(height: 24),

                _section('Buttons'),
                FilledButton(
                  onPressed: () {},
                  child: const Text('Generate Tour'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Generate AI Film'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: scheme.error),
                  onPressed: () {},
                  child: const Text('End Tour'),
                ),
                const SizedBox(height: 24),

                _section('Chips'),
                Wrap(
                  spacing: 8,
                  children: const [
                    Chip(label: Text('All Tours')),
                    Chip(label: Text('Recent')),
                    Chip(label: Text('Offline')),
                  ],
                ),
                const SizedBox(height: 24),

                _section('Card + input + switch'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shaniwar Wada', style: text.titleMedium),
                        Text('Royal Fortress', style: text.bodySmall),
                        const SizedBox(height: 12),
                        const TextField(
                          decoration: InputDecoration(
                            hintText: 'Start your adventure with a prompt...',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Voice Narration'),
                          value: _switchOn,
                          onChanged: (v) => setState(() => _switchOn = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: _dark ? AppColors.textTertiary : AppColors.textSecondary,
      ),
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
