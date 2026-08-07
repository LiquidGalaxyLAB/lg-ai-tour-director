import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  String? _path;

  @override
  void initState() {
    super.initState();
    _path = ref.read(aiFilmProvider).lastResult?.finalVideoPath;
    final path = _path;
    if (path != null) {
      final c = VideoPlayerController.file(File(path));
      _controller = c;
      c.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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
    final c = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Your AI Film is Ready')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // Player
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black,
              child: (c != null && c.value.isInitialized)
                  ? AspectRatio(
                      aspectRatio: c.value.aspectRatio == 0
                          ? 16 / 9
                          : c.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                              () => c.value.isPlaying ? c.pause() : c.play(),
                            ),
                            child: VideoPlayer(c),
                          ),
                          VideoProgressIndicator(c, allowScrubbing: true),
                          if (!c.value.isPlaying)
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
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
                _detail('Saved to', 'Downloads folder'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _snack('Saved to Downloads: ${_path ?? ''}'),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Open in Gallery'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saveTourKml,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Save Tour KML'),
          ),
          const SizedBox(height: 10),
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
