import 'package:flutter/material.dart';

import '../../shared/widgets/liquid_galaxy_logo.dart';

/// About (mockup 26): what the project is and the inspiration behind it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Text(
              'Explore the idea behind the project and the technology powering it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: LiquidGalaxyLogo(barHeight: 34)),
          const SizedBox(height: 4),
          Center(
            child: Text('Powered by Liquid Galaxy',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Tour Director',
            body:
                'Tour Director is an innovative platform designed to transform '
                'geographical exploration through AI-assisted tour generation. '
                'Built for the Liquid Galaxy platform, it lets users create '
                'immersive, high-definition visual journeys across the globe. By '
                'leveraging advanced language models and spatial data, Tour '
                'Director automates the complex process of KML creation, enabling '
                'anyone to direct a cinematic experience across multiple screens.',
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Inspiration',
            body:
                'Our goal is to foster a deeper engagement with our planet. By '
                'making geographic storytelling accessible and visually stunning, '
                'we aim to bridge the gap between static maps and dynamic '
                'exploration, encouraging curiosity about remote landscapes and '
                'urban environments alike.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
