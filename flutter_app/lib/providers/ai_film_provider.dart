import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location.dart';
import '../models/video_generation_result.dart';
import '../models/video_generation_settings.dart';

class AiFilmState {
  const AiFilmState({
    this.settings = const VideoGenerationSettings(),
    this.isGenerating = false,
    this.currentClipIndex = 0,
    this.totalClips = 0,
    this.currentStatus = '',
    this.lastResult,
  });

  final VideoGenerationSettings settings;
  final bool isGenerating;
  final int currentClipIndex;
  final int totalClips;
  final String currentStatus; // e.g. "Generating clip 2 of 10..."
  final VideoGenerationResult? lastResult;

  AiFilmState copyWith({
    VideoGenerationSettings? settings,
    bool? isGenerating,
    int? currentClipIndex,
    int? totalClips,
    String? currentStatus,
    VideoGenerationResult? lastResult,
  }) {
    return AiFilmState(
      settings: settings ?? this.settings,
      isGenerating: isGenerating ?? this.isGenerating,
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

  Future<void> generateFilm(List<TourLocation> locations) async {
    throw UnimplementedError('Implemented in Prompt 4');
  }
}

final aiFilmProvider = NotifierProvider<AiFilmNotifier, AiFilmState>(
  AiFilmNotifier.new,
);
