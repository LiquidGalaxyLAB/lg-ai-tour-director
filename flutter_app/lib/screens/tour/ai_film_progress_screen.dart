import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/location.dart';
import '../../models/video_generation_result.dart';
import '../../providers/ai_film_provider.dart';
import '../../services/video/video_provider_factory.dart';

class AiFilmProgressScreen extends ConsumerStatefulWidget {
  const AiFilmProgressScreen({super.key, required this.locations});

  final List<TourLocation> locations;

  @override
  ConsumerState<AiFilmProgressScreen> createState() =>
      _AiFilmProgressScreenState();
}

class _AiFilmProgressScreenState extends ConsumerState<AiFilmProgressScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      final result = await ref
          .read(aiFilmProvider.notifier)
          .generateFilm(widget.locations);
      if (!mounted || _navigated) return;
      if (result.success && result.finalVideoPath != null) {
        _toResult();
      } else {
        context.pop(); // cancelled with nothing generated → back
      }
    } on VideoGenerationException catch (e) {
      if (!mounted) return;
      _showErrorSheet(e);
    }
  }

  void _toResult() {
    _navigated = true;
    context.pushReplacement('/tour/ai-film-result', extra: widget.locations);
  }

  Future<void> _confirmCancel() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel generation?'),
        content: const Text(
          'The film will stop after the current clip finishes. Any clips '
          'already generated can still be stitched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel generation'),
          ),
        ],
      ),
    );
    if (yes ?? false) ref.read(aiFilmProvider.notifier).requestCancellation();
  }

  void _showErrorSheet(VideoGenerationException e) {
    final done =
        ref.read(aiFilmProvider).lastResult?.generatedClips ?? const [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'AI Film failed',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(e.userMessage, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Clips generated before error: ${done.length}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _start();
                },
                child: const Text('Try Again'),
              ),
              if (done.isNotEmpty)
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(aiFilmProvider.notifier).stitchClips(done);
                      if (mounted) _toResult();
                    } on VideoGenerationException catch (err) {
                      if (mounted) _showErrorSheet(err);
                    }
                  },
                  child: const Text('Keep Partial Film'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final film = ref.watch(aiFilmProvider);
    final total = film.totalClips;
    final progress = total > 0 ? film.currentClipIndex / total : 0.0;

    final settings = film.settings;
    final chunksPer = VideoProviderFactory.chunksNeeded(
      VideoProviderFactory.create(settings),
      settings.durationPerLocationSeconds,
    ).clamp(1, 9999);

    return PopScope(
      canPop: !film.isGenerating,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Generating AI Film'),
          automaticallyImplyLeading: !film.isGenerating,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(strokeWidth: 5),
              ),
              const SizedBox(height: 24),
              Text(
                total > 0
                    ? 'Clip ${film.currentClipIndex} of $total'
                    : 'Preparing…',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                film.currentStatus,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total > 0 ? progress.clamp(0.0, 1.0) : null,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var li = 0; li < widget.locations.length; li++)
                    _LocationChip(
                      name: widget.locations[li].name,
                      done: film.currentClipIndex > (li + 1) * chunksPer,
                    ),
                ],
              ),
              const Spacer(),
              if (film.isGenerating)
                TextButton(
                  onPressed: film.isCancelled ? null : _confirmCancel,
                  child: Text(
                    film.isCancelled ? 'Cancelling…' : 'Cancel Generation',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.name, required this.done});
  final String name;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = done ? const Color(0xFF34A853) : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
