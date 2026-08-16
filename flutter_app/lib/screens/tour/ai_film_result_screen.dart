import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../kml/assembler.dart';
import '../../models/location.dart';
import '../../providers/ai_film_provider.dart';
import '../../services/video/video_provider_factory.dart';

class AiFilmResultScreen extends ConsumerStatefulWidget {
  const AiFilmResultScreen({super.key, this.locations = const []});

  final List<TourLocation> locations;

  @override
  ConsumerState<AiFilmResultScreen> createState() => _AiFilmResultScreenState();
}

class _AiFilmResultScreenState extends ConsumerState<AiFilmResultScreen> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _path = ref.read(aiFilmProvider).lastResult?.finalVideoPath;
    if (_path != null && _path!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('🎬 Your AI film is ready!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// Opens the stitched MP4 in the device's native video player (Google Photos,
  /// MX Player, VLC, …) via an intent — no embedded player, any format.
  Future<void> _playVideo() async {
    final path = _path;
    if (path == null) return;
    final result = await OpenFilex.open(path, type: 'video/mp4');
    if (result.type != ResultType.done) {
      _snack('Could not open a video player: ${result.message}');
    }
  }

  Future<void> _share() async {
    final path = _path;
    if (path == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'video/mp4')],
        text: 'My AI Film — made with Tour Director',
      ),
    );
  }

  Future<void> _saveTourKml() async {
    if (widget.locations.isEmpty) {
      _snack('This film has no tour coordinates to export.');
      return;
    }
    final kml = KmlAssembler.buildTour(locations: widget.locations);
    if (kml == null) {
      _snack('No map coordinates in this tour, so there is no KML to save.');
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/tour_${DateTime.now().millisecondsSinceEpoch}.kml',
      );
      await file.writeAsString(kml);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'application/vnd.google-earth.kml+xml',
              name: 'tour.kml',
            ),
          ],
          subject: 'Liquid Galaxy tour',
        ),
      );
    } catch (e) {
      _snack('Could not export KML: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_path == null || _path!.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No video available. Generation may have failed.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final film = ref.watch(aiFilmProvider);
    final result = film.lastResult;
    final clips = result?.generatedClips ?? const [];
    final totalSeconds = clips.fold<int>(0, (s, c) => s + c.durationSeconds);
    final locationCount = clips.map((c) => c.locationIndex).toSet().length;
    final providerName = VideoProviderFactory.create(
      film.settings,
    ).providerName;

    return Scaffold(
      appBar: AppBar(title: const Text('Your AI Film is Ready')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // Partial-film notice (a clip failed / ran out of credits / cancelled).
          if (result?.partial == true && result?.message != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF29900).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF29900).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Color(0xFFF29900),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result!.message!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Hero: film generated.
          const SizedBox(height: 8),
          const Center(
            child: Icon(
              Icons.movie_creation_rounded,
              size: 80,
              color: Color(0xFF4285F4),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'AI Film Generated!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                _detail('Duration', '${totalSeconds}s'),
                _detail('Locations', '$locationCount'),
                _detail('Provider used', providerName),
                _detail('Clips stitched', '${clips.length}'),
                _detail('Saved to', 'Gallery › Movies'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Primary action: play in the native video player.
          FilledButton.icon(
            onPressed: _playVideo,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play Video'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Opens in your device video player',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Secondary actions.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _playVideo,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saveTourKml,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Save Tour KML'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Generate Another'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
