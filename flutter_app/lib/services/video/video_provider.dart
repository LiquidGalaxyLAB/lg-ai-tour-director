import 'package:dio/dio.dart';

import '../../models/video_generation_result.dart';
import '../../models/video_generation_settings.dart';

abstract class VideoProvider {
  String get providerName;

  int get maxClipDurationSeconds;

  bool get hasNativeAudio;

  Future<String> submitJob({
    required String prompt,
    required int durationSeconds,
  });

  Future<bool> isJobComplete(String jobId);

  Future<String> getVideoUrl(String jobId);

  Future<bool> testConnection();

  static const int _maxPolls = 120;
  static const Duration _pollInterval = Duration(seconds: 3);

  Future<String> generateAndWait({
    required String prompt,
    required int durationSeconds,
    required void Function(String status) onStatusUpdate,
  }) async {
    onStatusUpdate('Submitting to $providerName...');
    final jobId = await submitJob(
      prompt: prompt,
      durationSeconds: durationSeconds,
    );
    for (var attempt = 1; attempt <= _maxPolls; attempt++) {
      onStatusUpdate('Waiting for generation... ($attempt/$_maxPolls)');
      if (await isJobComplete(jobId)) {
        onStatusUpdate('Generation complete');
        return getVideoUrl(jobId);
      }
      await Future<void>.delayed(_pollInterval);
    }
    throw const VideoGenerationException(
      type: VideoGenerationError.unknown,
      rawMessage: 'timeout',
      userMessage:
          'Generation timed out after 10 minutes. The clip may still be '
          "processing on the provider's server.",
    );
  }

  Never throwClassified(
    Object error,
    VideoProviderType type, {
    String? modelId,
  }) {
    if (error is VideoGenerationException) throw error;
    Object raw = error;
    if (error is DioException) {
      final code = error.response?.statusCode;
      final body = error.response?.data ?? error.message ?? error;
      raw = '${code ?? ''} $body';
    }
    throw VideoGenerationException.classify(raw, type, modelId: modelId);
  }

  String? nestedString(dynamic data, List<Object> path) {
    dynamic cur = data;
    for (final key in path) {
      if (key is int && cur is List && key >= 0 && key < cur.length) {
        cur = cur[key];
      } else if (key is String && cur is Map && cur.containsKey(key)) {
        cur = cur[key];
      } else {
        return null;
      }
    }
    return cur is String ? cur : null;
  }
}
