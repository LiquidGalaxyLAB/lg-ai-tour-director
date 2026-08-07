import 'video_clip.dart';
import 'video_generation_settings.dart';

enum VideoGenerationError {
  insufficientCredits,
  invalidApiKey,
  modelNotFound,
  durationExceeded,
  rateLimited,
  downloadFailed,
  stitchFailed,
  unknown,
}

class VideoGenerationResult {
  const VideoGenerationResult({
    required this.success,
    this.finalVideoPath,
    this.error,
    this.generatedClips = const [],
    this.partial = false,
    this.message,
  });

  final bool success;
  final String? finalVideoPath;
  final VideoGenerationError? error;
  final List<VideoClip> generatedClips;

  /// True when fewer clips than requested were stitched (a clip failed — e.g.
  /// ran out of credits — or the user cancelled), but a film was still produced.
  final bool partial;

  /// Human-readable note shown on the result screen (why it's partial, etc.).
  final String? message;
}

class VideoGenerationException implements Exception {
  const VideoGenerationException({
    required this.type,
    required this.rawMessage,
    required this.userMessage,
  });

  final VideoGenerationError type;
  final String rawMessage;
  final String userMessage;

  static VideoGenerationException classify(
    dynamic rawError,
    VideoProviderType provider, {
    String? modelId,
  }) {
    final raw = rawError?.toString() ?? '';
    final lower = raw.toLowerCase();
    bool has(List<String> needles) => needles.any((n) => lower.contains(n));

    final providerLabel = provider.label;
    final model = (modelId == null || modelId.isEmpty)
        ? 'the configured model'
        : modelId;

    if (has(['insufficient', 'balance', 'credits', 'quota'])) {
      return VideoGenerationException(
        type: VideoGenerationError.insufficientCredits,
        rawMessage: raw,
        userMessage:
            'You have run out of credits on your $providerLabel account. '
            'Top up at your provider dashboard.',
      );
    }
    if (has(['invalid', 'unauthorized', '401', 'forbidden'])) {
      return VideoGenerationException(
        type: VideoGenerationError.invalidApiKey,
        rawMessage: raw,
        userMessage:
            'Your API key was rejected. Check it is correct and has video '
            'generation permissions.',
      );
    }
    if (has(['model', 'not found', '404'])) {
      return VideoGenerationException(
        type: VideoGenerationError.modelNotFound,
        rawMessage: raw,
        userMessage:
            "Model '$model' was not found. Check the model ID is correct for "
            'your provider.',
      );
    }
    if (has(['duration', 'length', 'too long', 'maximum'])) {
      return VideoGenerationException(
        type: VideoGenerationError.durationExceeded,
        rawMessage: raw,
        userMessage:
            'Requested duration exceeds provider limit. The app will '
            'automatically chunk clips — if you see this error, reduce '
            'duration per location.',
      );
    }
    if (has(['rate', '429', 'too many'])) {
      return VideoGenerationException(
        type: VideoGenerationError.rateLimited,
        rawMessage: raw,
        userMessage: 'You are being rate limited. Wait a moment and try again.',
      );
    }
    return VideoGenerationException(
      type: VideoGenerationError.unknown,
      rawMessage: raw,
      userMessage:
          'Provider returned an error: $raw This may be a credit, key, or '
          'configuration issue. Check your provider dashboard.',
    );
  }

  @override
  String toString() => 'VideoGenerationException($type): $userMessage';
}
