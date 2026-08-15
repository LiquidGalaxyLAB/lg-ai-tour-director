import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/location.dart';
import '../models/video_clip.dart';
import '../models/video_generation_result.dart';
import '../models/video_generation_settings.dart';
import '../services/video/video_provider_factory.dart';
import '../services/video/video_stitcher.dart';

class AiFilmState {
  const AiFilmState({
    this.settings = const VideoGenerationSettings(),
    this.isGenerating = false,
    this.isCancelled = false,
    this.currentClipIndex = 0,
    this.totalClips = 0,
    this.currentStatus = '',
    this.lastResult,
  });

  final VideoGenerationSettings settings;
  final bool isGenerating;
  final bool isCancelled; // set by the Cancel button; checked between clips
  final int currentClipIndex;
  final int totalClips;
  final String currentStatus; // e.g. "Generating clip 2 of 10..."
  final VideoGenerationResult? lastResult;

  AiFilmState copyWith({
    VideoGenerationSettings? settings,
    bool? isGenerating,
    bool? isCancelled,
    int? currentClipIndex,
    int? totalClips,
    String? currentStatus,
    VideoGenerationResult? lastResult,
  }) {
    return AiFilmState(
      settings: settings ?? this.settings,
      isGenerating: isGenerating ?? this.isGenerating,
      isCancelled: isCancelled ?? this.isCancelled,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      totalClips: totalClips ?? this.totalClips,
      currentStatus: currentStatus ?? this.currentStatus,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AiFilmNotifier extends Notifier<AiFilmState> {
  @override
  AiFilmState build() {
    loadSettings();
    return const AiFilmState();
  }

  Future<void> loadSettings() async {
    final saved = await VideoGenerationSettings.load();
    if (saved != null) {
      state = state.copyWith(settings: saved);
    }
  }

  Future<void> saveSettings(VideoGenerationSettings settings) async {
    await settings.save();
    state = state.copyWith(settings: settings);
  }

  void requestCancellation() {
    state = state.copyWith(isCancelled: true);
  }

  Future<VideoGenerationResult> generateFilm(
    List<TourLocation> locations,
  ) async {
    state = state.copyWith(
      isGenerating: true,
      isCancelled: false,
      currentClipIndex: 0,
      totalClips: 0,
      currentStatus: 'Starting AI Film generation...',
    );

    final settings = state.settings;
    final provider = VideoProviderFactory.create(settings);
    final allClips = <VideoClip>[];

    try {
      final chunksPerLocation = VideoProviderFactory.chunksNeeded(
        provider,
        settings.durationPerLocationSeconds,
      );
      final chunkDuration = VideoProviderFactory.chunkDuration(
        provider,
        settings.durationPerLocationSeconds,
      );
      final totalClips = locations.length * chunksPerLocation;
      state = state.copyWith(totalClips: totalClips);

      // Set if a clip fails mid-run; we stop spending and stitch what succeeded.
      VideoGenerationException? clipError;
      outer:
      for (var li = 0; li < locations.length; li++) {
        final location = locations[li];
        for (var ci = 0; ci < chunksPerLocation; ci++) {
          if (state.isCancelled) break outer; // check between clips only
          final clipNum = (li * chunksPerLocation) + ci + 1;

          state = state.copyWith(
            currentClipIndex: clipNum,
            currentStatus:
                'Generating clip $clipNum of $totalClips\n'
                '${location.name} (${ci + 1}/$chunksPerLocation)',
          );

          final prompt = _buildCinematicPrompt(location, ci);

          try {
            final videoUrl = await provider.generateAndWait(
              prompt: prompt,
              durationSeconds: chunkDuration,
              onStatusUpdate: (status) {
                state = state.copyWith(currentStatus: status);
              },
            );

            state = state.copyWith(
              currentStatus: 'Downloading clip $clipNum...',
            );
            final localPath = await VideoStitcher.downloadClip(
              url: videoUrl,
              filename:
                  'clip_${li}_${ci}_${DateTime.now().millisecondsSinceEpoch}'
                  '.mp4',
              onProgress: (p) {},
            );

            allClips.add(
              VideoClip(
                locationName: location.name,
                localPath: localPath,
                durationSeconds: chunkDuration,
                clipIndex: ci,
                locationIndex: li,
              ),
            );
          } on VideoGenerationException catch (e) {
            // Stop further generation but keep the clips already produced.
            clipError = e;
            break outer;
          }
        }
      }

      // Nothing usable: surface the real error, or a clean cancel.
      if (allClips.isEmpty) {
        if (clipError != null) {
          state = state.copyWith(
            isGenerating: false,
            currentStatus: 'Generation failed',
            lastResult: VideoGenerationResult(
              success: false,
              error: clipError.type,
            ),
          );
          throw clipError;
        }
        const result = VideoGenerationResult(success: false, generatedClips: []);
        state = state.copyWith(
          isGenerating: false,
          currentStatus: 'Cancelled',
          lastResult: result,
        );
        return result;
      }

      // At least one clip exists: stitch what we have (the "3 of 5" partial).
      final partial =
          clipError != null ||
          state.isCancelled ||
          allClips.length < totalClips;
      final message = clipError != null
          ? '${clipError.userMessage} '
                'Stitched the ${allClips.length} clip'
                '${allClips.length == 1 ? '' : 's'} generated before that.'
          : state.isCancelled
          ? 'Cancelled after ${allClips.length} of $totalClips clips. '
                'Stitched what was ready.'
          : null;

      state = state.copyWith(
        currentStatus: 'Stitching ${allClips.length} clips...',
      );
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/ai_film/'
          'tour_film_${DateTime.now().millisecondsSinceEpoch}.mp4';

      await VideoStitcher.stitch(
        inputPaths: allClips.map((c) => c.localPath).toList(),
        outputPath: outputPath,
        onProgress: (msg) => state = state.copyWith(currentStatus: msg),
      );

      state = state.copyWith(currentStatus: 'Saving film to your device...');
      final savedPath = await VideoStitcher.saveToDownloads(outputPath);

      await VideoStitcher.cleanupTempClips(
        allClips.map((c) => c.localPath).toList(),
      );

      final result = VideoGenerationResult(
        success: true,
        finalVideoPath: savedPath,
        generatedClips: allClips,
        partial: partial,
        message: message,
      );
      state = state.copyWith(
        isGenerating: false,
        currentStatus: partial ? 'Partial film ready' : 'Film ready!',
        lastResult: result,
      );
      return result;
    } on VideoGenerationException catch (e) {
      final result = VideoGenerationResult(
        success: false,
        error: e.type,
        generatedClips: allClips,
      );
      state = state.copyWith(
        isGenerating: false,
        currentStatus: 'Generation failed',
        lastResult: result,
      );
      rethrow;
    } catch (e) {
      final result = VideoGenerationResult(
        success: false,
        error: VideoGenerationError.unknown,
        generatedClips: allClips,
      );
      state = state.copyWith(
        isGenerating: false,
        currentStatus: 'Generation failed',
        lastResult: result,
      );
      throw VideoGenerationException(
        type: VideoGenerationError.unknown,
        rawMessage: e.toString(),
        userMessage: 'An unexpected error occurred: $e',
      );
    }
  }

  Future<VideoGenerationResult> stitchClips(List<VideoClip> clips) async {
    state = state.copyWith(
      isGenerating: true,
      currentStatus: 'Stitching ${clips.length} clips...',
    );
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/ai_film/'
          'tour_film_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await VideoStitcher.stitch(
        inputPaths: clips.map((c) => c.localPath).toList(),
        outputPath: outputPath,
        onProgress: (msg) => state = state.copyWith(currentStatus: msg),
      );
      final savedPath = await VideoStitcher.saveToDownloads(outputPath);
      await VideoStitcher.cleanupTempClips(
        clips.map((c) => c.localPath).toList(),
      );
      final result = VideoGenerationResult(
        success: true,
        finalVideoPath: savedPath,
        generatedClips: clips,
      );
      state = state.copyWith(
        isGenerating: false,
        currentStatus: 'Film ready!',
        lastResult: result,
      );
      return result;
    } on VideoGenerationException {
      state = state.copyWith(
        isGenerating: false,
        currentStatus: 'Stitch failed',
      );
      rethrow;
    }
  }

  /// Cinematic prompt per location + chunk (varies the camera angle per chunk).
  String _buildCinematicPrompt(TourLocation location, int chunkIndex) {
    const angles = [
      'Cinematic aerial drone shot sweeping over',
      'Slow cinematic push-in toward',
      'Epic wide establishing shot of',
      'Dramatic low-angle aerial view of',
      'Smooth orbital camera movement around',
    ];
    final angle = angles[chunkIndex % angles.length];
    final addressPart = (location.address?.isNotEmpty == true)
        ? ', ${location.address}'
        : '';
    return '$angle ${location.name}$addressPart. '
        '${location.whySignificant}. '
        'Golden hour lighting, 4K cinematic quality, smooth camera movement, '
        'no text overlays, documentary style, National Geographic quality.';
  }
}

final aiFilmProvider = NotifierProvider<AiFilmNotifier, AiFilmState>(
  AiFilmNotifier.new,
);
