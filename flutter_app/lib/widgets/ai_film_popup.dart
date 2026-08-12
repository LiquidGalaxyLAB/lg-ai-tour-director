import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location.dart';
import '../models/video_generation_settings.dart';
import '../providers/ai_film_provider.dart';
import '../services/video/video_cost.dart';

/// What the user chose in the post-tour AI Film sheet.
enum AiFilmChoice { generate, setUp, dismiss }

/// Post-tour bottom sheet offering AI Film. Returns the user's [AiFilmChoice]
/// (the caller handles navigation). Shows nothing when AI Film is disabled.
Future<AiFilmChoice?> showAiFilmPopup(
  BuildContext context,
  WidgetRef ref, {
  required List<TourLocation> locations,
}) {
  final settings = ref.read(aiFilmProvider).settings;
  if (!settings.isEnabled) {
    return Future<AiFilmChoice?>.value(AiFilmChoice.dismiss); // don't show
  }
  return showModalBottomSheet<AiFilmChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AiFilmPopup(locations: locations),
  );
}

class AiFilmPopup extends ConsumerWidget {
  const AiFilmPopup({super.key, required this.locations});

  final List<TourLocation> locations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(aiFilmProvider).settings;
    final ready = settings.isConfigured && settings.isEnabled;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎬', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Generate AI Film?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              ready
                  ? 'Turn this tour into a cinematic video using your AI video '
                        'provider.'
                  : 'Turn this tour into a cinematic video using your AI video '
                        'provider.\n\nSet up your AI video provider first.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (ready) ...[
              _costLine(
                context,
                settings.providerType,
                settings.modelId,
                settings.durationPerLocationSeconds,
                locations.length,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(AiFilmChoice.generate),
                  icon: const Icon(Icons.movie_creation_rounded),
                  label: const Text('Generate Film'),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(AiFilmChoice.dismiss),
                child: const Text('Maybe Later'),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(AiFilmChoice.setUp),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Set Up AI Film'),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(AiFilmChoice.dismiss),
                child: const Text('Skip'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _costLine(
    BuildContext context,
    VideoProviderType type,
    String modelId,
    int durationPerLocation,
    int locationCount,
  ) {
    final theme = Theme.of(context);
    final estimate = VideoCost.estimateUsd(
      type: type,
      modelId: modelId,
      durationPerLocation: durationPerLocation,
      locationCount: locationCount,
    );
    final text = estimate == null
        ? 'Estimated cost: unknown (custom provider)'
        : estimate == 0
        ? 'Estimated cost: Free (local model)'
        : 'Estimated cost for this tour: ~\$${estimate.toStringAsFixed(2)} '
              '($locationCount locations × ${durationPerLocation}s)';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
