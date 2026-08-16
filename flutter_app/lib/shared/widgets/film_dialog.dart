import 'package:flutter/material.dart';

/// Asks whether to generate an AI film of the tour, shown right before the tour
/// starts (the locked opt-in UX). Returns:
///  - `true`  → generate the film (Veo fires in parallel during the tour)
///  - `false` → normal tour, no film
///  - `null`  → cancelled (don't start)
Future<bool?> showFilmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        icon: Icon(
          Icons.movie_filter_outlined,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        title: const Text('Generate an AI film?'),
        content: const Text(
          'We can create a shareable cinematic film of this tour while you watch '
          'it on Liquid Galaxy. It will be ready right after the tour ends.\n\n'
          'Or start a normal tour without a film.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('No, just the tour'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Yes, make a film'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
